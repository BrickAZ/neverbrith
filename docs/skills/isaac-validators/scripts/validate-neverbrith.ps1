param(
    [string]$Root
)

$ErrorActionPreference = "Stop"

if (-not $Root) {
    $Root = Resolve-Path (Join-Path $PSScriptRoot "../../..")
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
        [xml]$doc = Get-Content -Raw -LiteralPath $path
        return $doc
    } catch {
        Add-Failure "XML parse failed: $path :: $($_.Exception.Message)"
        return $null
    }
}

function Resolve-AssetCandidates([string]$value) {
    $v = $value -replace "/", "\"
    $candidates = New-Object System.Collections.Generic.List[string]
    $candidates.Add((Join-Path $Root $v)) | Out-Null
    $candidates.Add((Join-Path $Root (Join-Path "resources" $v))) | Out-Null
    if ($v -like "gfx\*") {
        $candidates.Add((Join-Path $Root (Join-Path "resources" $v))) | Out-Null
    }
    if ($v -like "sfx\*" -or $v -like "music\*") {
        $candidates.Add((Join-Path $Root (Join-Path "resources" $v))) | Out-Null
    }
    return $candidates
}

function Test-AssetPath([string]$source, [string]$attrName, [string]$value) {
    if ($value -match "^(?:[A-Za-z]:\\|/)" ) {
        Add-Warning "Absolute asset path in $source [$attrName=$value]"
        return
    }
    $exists = $false
    foreach ($candidate in (Resolve-AssetCandidates $value)) {
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
                    Test-AssetPath $file.FullName $attribute.Name $value
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
    $nameSets = @{}
    foreach ($key in $docs.Keys) {
        if (-not $docs[$key]) { continue }
        $set = New-Object System.Collections.Generic.HashSet[string]
        foreach ($node in $docs[$key].SelectNodes("//*[@name]")) {
            $null = $set.Add($node.GetAttribute("name"))
        }
        $nameSets[$key] = $set
    }
    if ($nameSets.ContainsKey("base")) {
        foreach ($lang in @("en_us", "zh_cn")) {
            if (-not $nameSets.ContainsKey($lang)) { continue }
            foreach ($name in $nameSets["base"]) {
                if (-not $nameSets[$lang].Contains($name)) {
                    Add-Warning "items.$lang.xml may be missing item name '$name'"
                }
            }
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
                $null = Get-Content -Raw -LiteralPath $evalJson | ConvertFrom-Json
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
