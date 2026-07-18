param(
    [string]$Root
)

$ErrorActionPreference = "Stop"

if (-not $Root) {
    $Root = Resolve-Path (Join-Path $PSScriptRoot "../../../..")
} else {
    $Root = Resolve-Path $Root
}

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$message) {
    $failures.Add($message) | Out-Null
}

function Add-Warning([string]$message) {
    $warnings.Add($message) | Out-Null
}

function Test-Xml([string]$path) {
    try {
        [xml]$doc = Get-Content -Raw -Encoding UTF8 -LiteralPath $path
        return $doc
    } catch {
        Add-Failure "XML parse failed: $path :: $($_.Exception.Message)"
        return $null
    }
}

function Resolve-AssetCandidates([string]$value, [string]$basePath) {
    $v = $value -replace "/", "\"
    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add((Join-Path $Root $v)) | Out-Null
    $candidates.Add((Join-Path $Root (Join-Path "resources" $v))) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($basePath)) {
        $base = $basePath -replace "/", "\"
        $candidates.Add((Join-Path $Root (Join-Path "resources" (Join-Path $base $v)))) | Out-Null
    }
    if ($v -like "gfx\*") {
        $candidates.Add((Join-Path $Root (Join-Path "resources" $v))) | Out-Null
    }
    if ($v -match "\.png$") {
        $candidates.Add((Join-Path $Root (Join-Path "resources\gfx\Items\Collectibles" $v))) | Out-Null
        $candidates.Add((Join-Path $Root (Join-Path "resources\gfx\Items\Trinkets" $v))) | Out-Null
        $candidates.Add((Join-Path $Root (Join-Path "resources\gfx\PocketItems" $v))) | Out-Null
    }
    if ($v -match "\.anm2$") {
        $candidates.Add((Join-Path $Root (Join-Path "resources\gfx" $v))) | Out-Null
        $candidates.Add((Join-Path $Root (Join-Path "resources\gfx\characters" $v))) | Out-Null
    }
    if ($v -match "\.(ogg|mp3|wav)$") {
        $candidates.Add((Join-Path $Root (Join-Path "resources\music" $v))) | Out-Null
        $candidates.Add((Join-Path $Root (Join-Path "resources\sfx" $v))) | Out-Null
    }
    return $candidates
}

function Test-AssetPath([string]$source, [string]$attrName, [string]$value, [string]$basePath) {
    if ($value -match "^(?:[A-Za-z]:\\|/)" ) {
        Add-Warning "Absolute asset path in $source [$attrName=$value]"
        return
    }
    $exists = $false
    foreach ($candidate in (Resolve-AssetCandidates $value $basePath)) {
        if (Test-Path -LiteralPath $candidate) {
            $exists = $true
            break
        }
    }
    if (-not $exists) {
        Add-Warning "Asset path not found from $source [$attrName=$value]"
    }
}

Write-Output "Validating neverbrith at $Root"

$contentDir = Join-Path $Root "content"
if (Test-Path -LiteralPath $contentDir) {
    foreach ($file in Get-ChildItem -LiteralPath $contentDir -Filter "*.xml") {
        $doc = Test-Xml $file.FullName
        if (-not $doc) { continue }
        $assetBase = ""
        if ($doc.DocumentElement -and $doc.DocumentElement.HasAttribute("gfxroot")) {
            $assetBase = $doc.DocumentElement.GetAttribute("gfxroot")
        }

        foreach ($attr in @("id", "name")) {
            $nodes = $doc.SelectNodes("//*[@$attr]")
            $groups = @{}
            foreach ($node in $nodes) {
                $value = $node.GetAttribute($attr)
                if ([string]::IsNullOrWhiteSpace($value)) { continue }
                $key = "$($node.Name):$value"
                if (-not $groups.ContainsKey($key)) {
                    $groups[$key] = 0
                }
                $groups[$key] += 1
            }
            foreach ($key in $groups.Keys) {
                if ($groups[$key] -gt 1) {
                    Add-Warning "Duplicate $attr in $($file.FullName): $key appears $($groups[$key]) times"
                }
            }
        }

        $assetNodes = $doc.SelectNodes("//*[@*]")
        foreach ($node in $assetNodes) {
            foreach ($attribute in $node.Attributes) {
                $value = [string]$attribute.Value
                if ($value -match "\.(anm2|png|wav|ogg|mp3|fs|fsh)$") {
                    Test-AssetPath $file.FullName $attribute.Name $value $assetBase
                }
            }
        }
    }
} else {
    Add-Warning "No content directory found: $contentDir"
}

$itemsBase = Join-Path $contentDir "items.xml"
$itemsEn = Join-Path $contentDir "items.en_us.xml"
$itemsZh = Join-Path $contentDir "items.zh_cn.xml"
if ((Test-Path $itemsBase) -and (Test-Path $itemsEn) -and (Test-Path $itemsZh)) {
    $docs = @{
        "base" = Test-Xml $itemsBase
        "en_us" = Test-Xml $itemsEn
        "zh_cn" = Test-Xml $itemsZh
    }
    $baseCount = 0
    if ($docs["base"]) {
        $baseCount = $docs["base"].SelectNodes("/items/*[@name]").Count
    }
    foreach ($lang in @("en_us", "zh_cn")) {
        if (-not $docs[$lang]) { continue }
        $count = $docs[$lang].SelectNodes("/items/*[@name]").Count
        if ($baseCount -ne $count) {
            Add-Warning "items.$lang.xml has $count named entries, base items.xml has $baseCount"
        }
    }
}

$skillsDir = Join-Path $Root "docs\skills"
if (Test-Path -LiteralPath $skillsDir) {
    foreach ($skill in Get-ChildItem -LiteralPath $skillsDir -Directory) {
        $skillMd = Join-Path $skill.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $skillMd)) {
            Add-Failure "Missing SKILL.md in $($skill.FullName)"
        }
        $evalJson = Join-Path $skill.FullName "evals\evals.json"
        if (Test-Path -LiteralPath $evalJson) {
            try {
                $null = Get-Content -Raw -Encoding UTF8 -LiteralPath $evalJson | ConvertFrom-Json
            } catch {
                Add-Failure "Invalid evals.json: $evalJson :: $($_.Exception.Message)"
            }
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Output ""
    Write-Output "Warnings:"
    foreach ($warning in $warnings) {
        Write-Output "WARN $warning"
    }
}

if ($failures.Count -gt 0) {
    Write-Output ""
    Write-Output "Failures:"
    foreach ($failure in $failures) {
        Write-Output "FAIL $failure"
    }
    exit 1
}

Write-Output ""
Write-Output "Static validation completed with $($warnings.Count) warning(s) and 0 failure(s)."
exit 0
