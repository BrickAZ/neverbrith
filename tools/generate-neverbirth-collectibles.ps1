param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"
$rootPath = (Resolve-Path $Root).Path
$sourcePath = Join-Path $rootPath "content/items.xml"
$outputDirectory = Join-Path $rootPath "generated"
$outputPath = Join-Path $outputDirectory "neverbirth_collectibles.lua"
$utf8 = [System.Text.UTF8Encoding]::new($false)

[xml]$xml = [System.IO.File]::ReadAllText($sourcePath, $utf8)
$rows = @($xml.items.active) + @($xml.items.passive) + @($xml.items.familiar) |
    Where-Object { $_ -and $_.id -and $_.name } |
    ForEach-Object {
        [pscustomobject]@{
            LocalId = [int]$_.id
            EnglishName = [string]$_.name
        }
    } |
    Sort-Object LocalId

$duplicateIds = @($rows | Group-Object LocalId | Where-Object Count -ne 1)
if ($duplicateIds.Count -gt 0) {
    throw "content/items.xml contains duplicate collectible local IDs: $($duplicateIds.Name -join ', ')"
}

foreach ($row in $rows) {
    $names = [System.Collections.Generic.List[string]]::new()
    $names.Add($row.EnglishName)
    $row | Add-Member -NotePropertyName CandidateNames -NotePropertyValue $names
}
foreach ($localeRelativePath in "content/items.en_us.xml", "content/items.zh_cn.xml") {
    $localePath = Join-Path $rootPath $localeRelativePath
    [xml]$localeXml = [System.IO.File]::ReadAllText($localePath, $utf8)
    $localeEntries = @($localeXml.items.active) + @($localeXml.items.passive) + @($localeXml.items.familiar) |
        Where-Object { $_ -and $_.id -and $_.name }
    if ($localeEntries.Count -ne $rows.Count) {
        throw "$localeRelativePath collectible count does not match content/items.xml"
    }
    foreach ($entry in $localeEntries) {
        $row = $rows | Where-Object LocalId -eq ([int]$entry.id) | Select-Object -First 1
        if (-not $row) { throw "$localeRelativePath contains unknown local ID $($entry.id)" }
        $name = [string]$entry.name
        if (-not $row.CandidateNames.Contains($name)) { $row.CandidateNames.Add($name) }
    }
}

function ConvertTo-LuaString([string]$Value) {
    return '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

$lines = @(
    "-- Generated from content/items.xml by tools/generate-neverbirth-collectibles.ps1."
    "-- Do not edit by hand."
    "return {"
)
foreach ($row in $rows) {
    $candidateNames = ($row.CandidateNames | ForEach-Object { ConvertTo-LuaString $_ }) -join ", "
    $lines += "    { localId = $($row.LocalId), englishName = $(ConvertTo-LuaString $row.EnglishName), names = { $candidateNames } },"
}
$lines += "}"
$lines += ""

[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
[System.IO.File]::WriteAllLines($outputPath, $lines, $utf8)
Write-Output "Generated $($rows.Count) neverbrith collectible rows at $outputPath"
