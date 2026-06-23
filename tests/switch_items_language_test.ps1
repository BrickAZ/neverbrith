$ErrorActionPreference = 'Stop'

function Assert-EqualText {
    param(
        [string]$Actual,
        [string]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message`: expected text did not match"
    }
}

function Read-NormalizedText {
    param([string]$Path)

    return (Get-Content -Raw -LiteralPath $Path) -replace "`r`n", "`n"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$itemsPath = Join-Path $repoRoot 'content/items.xml'
$itempoolsPath = Join-Path $repoRoot 'content/itempools.xml'
$englishTemplatePath = Join-Path $repoRoot 'content/items.en_us.xml'
$chineseTemplatePath = Join-Path $repoRoot 'content/items.zh_cn.xml'
$englishPoolsTemplatePath = Join-Path $repoRoot 'content/itempools.en_us.xml'
$chinesePoolsTemplatePath = Join-Path $repoRoot 'content/itempools.zh_cn.xml'
$switchScriptPath = Join-Path $repoRoot 'tools/switch-items-language.ps1'
$originalItems = [System.IO.File]::ReadAllBytes($itemsPath)
$originalItempools = [System.IO.File]::ReadAllBytes($itempoolsPath)

try {
    & $switchScriptPath -Language zh_cn | Out-Null
    Assert-EqualText `
        -Actual (Read-NormalizedText $itemsPath) `
        -Expected (Read-NormalizedText $chineseTemplatePath) `
        -Message 'zh_cn switch should copy the Chinese template'
    Assert-EqualText `
        -Actual (Read-NormalizedText $itempoolsPath) `
        -Expected (Read-NormalizedText $chinesePoolsTemplatePath) `
        -Message 'zh_cn switch should copy the Chinese itempools template'

    & $switchScriptPath -Language en_us | Out-Null
    Assert-EqualText `
        -Actual (Read-NormalizedText $itemsPath) `
        -Expected (Read-NormalizedText $englishTemplatePath) `
        -Message 'en_us switch should copy the English template'
    Assert-EqualText `
        -Actual (Read-NormalizedText $itempoolsPath) `
        -Expected (Read-NormalizedText $englishPoolsTemplatePath) `
        -Message 'en_us switch should copy the English itempools template'

    $beforeInvalidSwitch = [System.IO.File]::ReadAllBytes($itemsPath)
    $beforeInvalidPoolsSwitch = [System.IO.File]::ReadAllBytes($itempoolsPath)
    $invalidOutput = $null
    $invalidFailed = $false
    try {
        $invalidOutput = & $switchScriptPath -Language fr 2>&1
    }
    catch {
        $invalidFailed = $true
        $invalidOutput = $_.Exception.Message
    }
    if (-not $invalidFailed) {
        throw 'switch script should fail for unsupported languages'
    }
    Assert-EqualText `
        -Actual ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($itemsPath))) `
        -Expected ([Convert]::ToBase64String($beforeInvalidSwitch)) `
        -Message 'invalid language should not modify items.xml'
    Assert-EqualText `
        -Actual ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($itempoolsPath))) `
        -Expected ([Convert]::ToBase64String($beforeInvalidPoolsSwitch)) `
        -Message 'invalid language should not modify itempools.xml'
    if (-not (($invalidOutput | Out-String) -match 'Unsupported language')) {
        throw 'invalid language should report a clear unsupported-language error'
    }
}
finally {
    [System.IO.File]::WriteAllBytes($itemsPath, $originalItems)
    [System.IO.File]::WriteAllBytes($itempoolsPath, $originalItempools)
}

Write-Output 'switch items language tests passed'
