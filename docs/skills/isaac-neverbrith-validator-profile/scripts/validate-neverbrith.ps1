param(
    [string]$Root
)

$ErrorActionPreference = "Stop"

if (-not $Root) {
    $Root = Resolve-Path .
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

function Test-EntityAnm2([string]$entityName, [string]$anm2Path) {
    $doc = Test-Xml $anm2Path
    if (-not $doc) { return }

    if (-not $doc.DocumentElement -or $doc.DocumentElement.Name -ne "AnimatedActor") {
        Add-Failure "Registered entity '$entityName' does not use a valid AnimatedActor ANM2: $anm2Path"
        return
    }

    $spritesheets = $doc.SelectNodes("//Spritesheet")
    if (-not $spritesheets -or $spritesheets.Count -eq 0) {
        Add-Failure "Registered entity '$entityName' ANM2 has no spritesheet: $anm2Path"
    } else {
        foreach ($sheet in $spritesheets) {
            $sheetPath = $sheet.GetAttribute("Path")
            if ([string]::IsNullOrWhiteSpace($sheetPath)) {
                Add-Failure "Registered entity '$entityName' ANM2 has a spritesheet without Path: $anm2Path"
                continue
            }
            $resolvedSheet = Join-Path (Split-Path -Parent $anm2Path) ($sheetPath -replace "/", "\")
            if (-not (Test-Path -LiteralPath $resolvedSheet)) {
                Add-Failure "Registered entity '$entityName' ANM2 spritesheet is missing: $resolvedSheet"
            }
        }
    }

    $animations = $doc.SelectNodes("/AnimatedActor/Animations/Animation")
    $defaultAnimation = $doc.SelectSingleNode("/AnimatedActor/Animations")
    $defaultName = if ($defaultAnimation) { $defaultAnimation.GetAttribute("DefaultAnimation") } else { "" }
    if ([string]::IsNullOrWhiteSpace($defaultName)) {
        Add-Failure "Registered entity '$entityName' ANM2 has no DefaultAnimation: $anm2Path"
    } elseif (-not ($animations | Where-Object { $_.GetAttribute("Name") -eq $defaultName })) {
        Add-Failure "Registered entity '$entityName' DefaultAnimation '$defaultName' is not defined: $anm2Path"
    }
}

function Test-RegisteredEntities([string]$entitiesPath) {
    $knownNames = @{}
    if (-not (Test-Path -LiteralPath $entitiesPath)) {
        return $knownNames
    }

    $doc = Test-Xml $entitiesPath
    if (-not $doc) { return $knownNames }
    $assetBase = if ($doc.DocumentElement -and $doc.DocumentElement.HasAttribute("anm2root")) { $doc.DocumentElement.GetAttribute("anm2root") } else { "" }
    $pairs = @{}

    foreach ($entity in $doc.SelectNodes("/entities/entity")) {
        $entityName = $entity.GetAttribute("name")
        $idRaw = $entity.GetAttribute("id")
        $variantRaw = $entity.GetAttribute("variant")
        $anm2Relative = $entity.GetAttribute("anm2path")

        if ([string]::IsNullOrWhiteSpace($entityName)) {
            Add-Failure "Registered entity is missing name: $entitiesPath"
        } else {
            $knownNames[$entityName] = $true
        }
        if ($idRaw -notmatch "^\d+$" -or [int]$idRaw -le 0) {
            Add-Failure "Registered entity '$entityName' has invalid id '$idRaw': $entitiesPath"
        }
        if ($variantRaw -notmatch "^\d+$" -or [int]$variantRaw -le 0) {
            Add-Failure "Registered entity '$entityName' has invalid variant '$variantRaw': $entitiesPath"
        }

        $pair = "${idRaw}:${variantRaw}"
        if ($pairs.ContainsKey($pair)) {
            Add-Failure "Registered entity type/variant is duplicated: $pair in $entitiesPath"
        } else {
            $pairs[$pair] = $true
        }

        if ([string]::IsNullOrWhiteSpace($anm2Relative)) {
            Add-Failure "Registered entity '$entityName' has no anm2path: $entitiesPath"
            continue
        }

        $anm2Path = Join-Path $Root (Join-Path "resources" (Join-Path ($assetBase -replace "/", "\") ($anm2Relative -replace "/", "\")))
        if (-not (Test-Path -LiteralPath $anm2Path)) {
            Add-Failure "Registered entity '$entityName' ANM2 is missing: $anm2Path"
            continue
        }
        Test-EntityAnm2 $entityName $anm2Path
    }

    return $knownNames
}

function Test-OwnedEntityLookups([hashtable]$knownNames) {
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -Filter "*.lua") {
        if ($file.FullName -match "[\\/]tests[\\/]") { continue }
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        foreach ($match in [regex]::Matches($source, 'GetEntityVariantByName\s*\(\s*["'']([^"'']+)["'']')) {
            $name = $match.Groups[1].Value
            if (-not $knownNames.ContainsKey($name)) {
                Add-Warning "Lua resolves unregistered entity name '$name' in $($file.FullName); this is only safe behind an explicit optional-mod guard"
            }
        }
    }
}

function Test-PocketItemShape([string]$pocketItemsPath) {
    if (-not (Test-Path -LiteralPath $pocketItemsPath)) { return }
    $doc = Test-Xml $pocketItemsPath
    if (-not $doc) { return }
    $seen = @{}

    foreach ($node in $doc.SelectNodes("/pocketitems/card | /pocketitems/rune")) {
        $kind = $node.Name
        $idRaw = $node.GetAttribute("id")
        $name = $node.GetAttribute("name")
        $pickupRaw = $node.GetAttribute("pickup")
        $hud = $node.GetAttribute("hud")
        $key = "${kind}:${idRaw}"

        if ($idRaw -notmatch "^\d+$" -or [int]$idRaw -le 0) {
            Add-Failure "Pocket $kind '$name' has invalid id '$idRaw': $pocketItemsPath"
        }
        if ($seen.ContainsKey($key)) {
            Add-Failure "Pocket $kind id is duplicated: $key in $pocketItemsPath"
        } else {
            $seen[$key] = $true
        }
        if ([string]::IsNullOrWhiteSpace($name)) {
            Add-Failure "Pocket $kind id '$idRaw' has no name: $pocketItemsPath"
        }
        if ($pickupRaw -notmatch "^\d+$" -or [int]$pickupRaw -le 0) {
            Add-Failure "Pocket $kind '$name' has invalid pickup '$pickupRaw': $pocketItemsPath"
        }
        if ([string]::IsNullOrWhiteSpace($hud)) {
            Add-Failure "Pocket $kind '$name' has no hud key: $pocketItemsPath"
        }
    }
}

function Test-CallbackRegistrationContracts {
    $luaFiles = Get-ChildItem -LiteralPath $Root -Recurse -Filter "*.lua" |
        Where-Object { $_.FullName -notmatch "[\\/]tests[\\/]" }
    $definedHandlers = @{}
    foreach ($file in $luaFiles) {
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        foreach ($match in [regex]::Matches($source, 'function\s+Neverbirth[:.]([A-Za-z0-9_]+)\s*\(')) {
            $definedHandlers[$match.Groups[1].Value] = $true
        }
    }

    $seen = @{}
    $pattern = 'Neverbirth:AddCallback\s*\(\s*ModCallbacks\.(MC_[A-Z_]+)\s*,\s*Neverbirth\.([A-Za-z0-9_]+)(?:\s*,\s*([^\)]+))?\s*\)'
    foreach ($file in $luaFiles) {
        $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $file.FullName
        foreach ($match in [regex]::Matches($source, $pattern)) {
            $callback = $match.Groups[1].Value
            $handler = $match.Groups[2].Value
            $filter = ($match.Groups[3].Value -replace '\s+', ' ').Trim()
            if (-not $definedHandlers.ContainsKey($handler)) {
                Add-Failure "Callback $callback registers missing Neverbirth handler '$handler' in $($file.FullName)"
            }

            $key = "${callback}:${handler}:${filter}"
            if ($seen.ContainsKey($key)) {
                Add-Warning "Callback registration is duplicated: $key in $($file.FullName) and $($seen[$key])"
            } else {
                $seen[$key] = $file.FullName
            }
        }
    }
}

function Test-ItemPoolNumber([string]$source, [string]$field, [string]$value, [bool]$mustBePositive) {
    if ([string]::IsNullOrWhiteSpace($value)) { return }
    if ($value -notmatch '^\d+(?:\.\d+)?$') {
        Add-Failure "Invalid numeric $field '$value' in $source"
        return
    }
    if ($mustBePositive -and [double]$value -le 0) {
        Add-Failure "$field must be positive in $source, got '$value'"
    }
}

function Test-ItemPoolContracts([string]$contentDirectory) {
    $variants = @(
        @{ Key = 'base'; Items = (Join-Path $contentDirectory 'items.xml'); Pools = (Join-Path $contentDirectory 'itempools.xml') },
        @{ Key = 'en_us'; Items = (Join-Path $contentDirectory 'items.en_us.xml'); Pools = (Join-Path $contentDirectory 'itempools.en_us.xml') },
        @{ Key = 'zh_cn'; Items = (Join-Path $contentDirectory 'items.zh_cn.xml'); Pools = (Join-Path $contentDirectory 'itempools.zh_cn.xml') }
    )
    $poolDocs = @{}

    foreach ($variant in $variants) {
        if (-not (Test-Path -LiteralPath $variant.Items) -or -not (Test-Path -LiteralPath $variant.Pools)) { continue }
        $itemsDoc = Test-Xml $variant.Items
        $poolsDoc = Test-Xml $variant.Pools
        if (-not $itemsDoc -or -not $poolsDoc) { continue }
        $poolDocs[$variant.Key] = $poolsDoc

        $itemNames = @{}
        foreach ($item in $itemsDoc.SelectNodes('/items/*[@name]')) {
            $itemNames[$item.GetAttribute('name')] = $true
        }
        $seenPools = @{}
        foreach ($pool in $poolsDoc.SelectNodes('/ItemPools/Pool')) {
            $poolName = $pool.GetAttribute('Name')
            if ([string]::IsNullOrWhiteSpace($poolName)) {
                Add-Failure "Unnamed item pool in $($variant.Pools)"
            } elseif ($seenPools.ContainsKey($poolName)) {
                Add-Failure "Duplicate item pool '$poolName' in $($variant.Pools)"
            } else {
                $seenPools[$poolName] = $true
            }

            $seenItems = @{}
            foreach ($entry in $pool.SelectNodes('./Item')) {
                $name = $entry.GetAttribute('Name')
                if ([string]::IsNullOrWhiteSpace($name) -or -not $itemNames.ContainsKey($name)) {
                    Add-Failure "Pool '$poolName' references unknown item '$name' in $($variant.Pools)"
                }
                if ($seenItems.ContainsKey($name)) {
                    Add-Warning "Pool '$poolName' contains duplicate item '$name' in $($variant.Pools)"
                } else {
                    $seenItems[$name] = $true
                }
                Test-ItemPoolNumber "$($variant.Pools) [$poolName/$name]" 'Weight' $entry.GetAttribute('Weight') $true
                Test-ItemPoolNumber "$($variant.Pools) [$poolName/$name]" 'DecreaseBy' $entry.GetAttribute('DecreaseBy') $false
                Test-ItemPoolNumber "$($variant.Pools) [$poolName/$name]" 'RemoveOn' $entry.GetAttribute('RemoveOn') $false
            }
        }
    }

    if ($poolDocs.ContainsKey('base')) {
        $basePools = $poolDocs['base'].SelectNodes('/ItemPools/Pool')
        foreach ($language in @('en_us', 'zh_cn')) {
            if (-not $poolDocs.ContainsKey($language)) { continue }
            $localizedPools = $poolDocs[$language].SelectNodes('/ItemPools/Pool')
            if ($basePools.Count -ne $localizedPools.Count) {
                Add-Failure "itempools.$language.xml has $($localizedPools.Count) pools, base itempools.xml has $($basePools.Count)"
                continue
            }
            for ($index = 0; $index -lt $basePools.Count; $index++) {
                $basePool = $basePools[$index]
                $localizedPool = $localizedPools[$index]
                if ($basePool.GetAttribute('Name') -ne $localizedPool.GetAttribute('Name')) {
                    Add-Failure "itempools.$language.xml pool order/name differs at index $index"
                }
                $baseEntries = $basePool.SelectNodes('./Item')
                $localizedEntries = $localizedPool.SelectNodes('./Item')
                if ($baseEntries.Count -ne $localizedEntries.Count) {
                    Add-Failure "itempools.$language.xml pool '$($basePool.GetAttribute('Name'))' has $($localizedEntries.Count) items, base has $($baseEntries.Count)"
                    continue
                }
                for ($entryIndex = 0; $entryIndex -lt $baseEntries.Count; $entryIndex++) {
                    foreach ($field in @('Weight', 'DecreaseBy', 'RemoveOn')) {
                        if ($baseEntries[$entryIndex].GetAttribute($field) -ne $localizedEntries[$entryIndex].GetAttribute($field)) {
                            Add-Failure "itempools.$language.xml differs from base at pool '$($basePool.GetAttribute('Name'))', entry $entryIndex, field $field"
                        }
                    }
                }
            }
        }
    }
}

function Test-GeneratedCollectibleRegistry {
    $generator = Join-Path $Root "tools\generate-neverbirth-collectibles.ps1"
    if (-not (Test-Path -LiteralPath $generator)) {
        Add-Failure "Neverbirth collectible registry generator is missing: $generator"
        return
    }

    try {
        & $generator -Root $Root -Check | ForEach-Object { Write-Output $_ }
    } catch {
        Add-Failure "Neverbirth collectible registry is not synchronized with content/items*.xml :: $($_.Exception.Message)"
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

$ownedEntityNames = Test-RegisteredEntities (Join-Path $contentDir "entities2.xml")
Test-OwnedEntityLookups $ownedEntityNames
Test-PocketItemShape (Join-Path $contentDir "pocketitems.xml")
Test-CallbackRegistrationContracts
Test-ItemPoolContracts $contentDir
Test-GeneratedCollectibleRegistry

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
        if ($skill.Name -in @('tests')) { continue }
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
        foreach ($artifact in Get-ChildItem -LiteralPath $skill.FullName -Recurse -File) {
            if ($artifact.Extension -notin @('.md', '.json')) { continue }
            $source = Get-Content -Raw -Encoding UTF8 -LiteralPath $artifact.FullName
            if ($source -match '(?i)\b(?:ysd|reverie)\b|(?:[A-Za-z]:[\\/]|file://)') {
                Add-Failure "Skill must be self-contained; external source marker found: $($artifact.FullName)"
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

