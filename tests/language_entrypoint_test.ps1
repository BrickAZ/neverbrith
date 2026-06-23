$ErrorActionPreference = 'Stop'

function Assert-EqualText {
    param(
        [string]$Actual,
        [string]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message`: expected '$Expected', got '$Actual'"
    }
}

function Assert-ContainsText {
    param(
        [string]$Text,
        [string]$Pattern,
        [string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw "$Message`: '$Text' did not match '$Pattern'"
    }
}

function Invoke-Tool {
    param(
        [string]$ScriptPath,
        [string[]]$ToolArguments = @()
    )

    $output = powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @ToolArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw ($output | Out-String).Trim()
    }
    return ($output | Out-String).Trim()
}

function Copy-TestFile {
    param(
        [string]$Source,
        [string]$Destination
    )

    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$itemsPath = Join-Path $repoRoot 'content/items.xml'
$itempoolsPath = Join-Path $repoRoot 'content/itempools.xml'
$itemsEnPath = Join-Path $repoRoot 'content/items.en_us.xml'
$itemsZhPath = Join-Path $repoRoot 'content/items.zh_cn.xml'
$itempoolsEnPath = Join-Path $repoRoot 'content/itempools.en_us.xml'
$itempoolsZhPath = Join-Path $repoRoot 'content/itempools.zh_cn.xml'
$checkScriptPath = Join-Path $repoRoot 'tools/check-items-language.ps1'
$startScriptPath = Join-Path $repoRoot 'tools/start-neverbrith.ps1'
$originalItems = [System.IO.File]::ReadAllBytes($itemsPath)
$originalItempools = [System.IO.File]::ReadAllBytes($itempoolsPath)

try {
    Copy-TestFile $itemsEnPath $itemsPath
    Copy-TestFile $itempoolsEnPath $itempoolsPath
    Assert-EqualText `
        -Actual (Invoke-Tool -ScriptPath $checkScriptPath) `
        -Expected 'en_us' `
        -Message 'check script should identify English playable XML'

    Copy-TestFile $itemsZhPath $itemsPath
    Copy-TestFile $itempoolsZhPath $itempoolsPath
    Assert-EqualText `
        -Actual (Invoke-Tool -ScriptPath $checkScriptPath) `
        -Expected 'zh_cn' `
        -Message 'check script should identify Chinese playable XML'

    Copy-TestFile $itemsZhPath $itemsPath
    Copy-TestFile $itempoolsEnPath $itempoolsPath
    Assert-EqualText `
        -Actual (Invoke-Tool -ScriptPath $checkScriptPath) `
        -Expected 'mixed' `
        -Message 'check script should identify mixed playable XML'

    Set-Content -LiteralPath $itemsPath -Value '<items version="1" />' -NoNewline
    Set-Content -LiteralPath $itempoolsPath -Value '<ItemPools />' -NoNewline
    Assert-EqualText `
        -Actual (Invoke-Tool -ScriptPath $checkScriptPath) `
        -Expected 'unknown' `
        -Message 'check script should identify unknown playable XML'

    $zhOutput = Invoke-Tool -ScriptPath $startScriptPath -ToolArguments @('-Language', 'zh_cn', '-NoLaunch')
    Assert-ContainsText `
        -Text $zhOutput `
        -Pattern 'Language synchronized: zh_cn' `
        -Message 'start script should report Chinese synchronization'
    Assert-EqualText `
        -Actual (Invoke-Tool -ScriptPath $checkScriptPath) `
        -Expected 'zh_cn' `
        -Message 'start script should leave playable XML synchronized to Chinese'

    $enOutput = Invoke-Tool -ScriptPath $startScriptPath -ToolArguments @('-Language', 'en_us', '-NoLaunch')
    Assert-ContainsText `
        -Text $enOutput `
        -Pattern 'Language synchronized: en_us' `
        -Message 'start script should report English synchronization'
    Assert-EqualText `
        -Actual (Invoke-Tool -ScriptPath $checkScriptPath) `
        -Expected 'en_us' `
        -Message 'start script should leave playable XML synchronized to English'

    $invalidFailed = $false
    try {
        Invoke-Tool -ScriptPath $startScriptPath -ToolArguments @('-Language', 'fr', '-NoLaunch') | Out-Null
    }
    catch {
        $invalidFailed = $true
        Assert-ContainsText `
            -Text $_.Exception.Message `
            -Pattern 'Unsupported language' `
            -Message 'start script should reject unsupported languages'
    }
    if (-not $invalidFailed) {
        throw 'start script should fail for unsupported languages'
    }
}
finally {
    [System.IO.File]::WriteAllBytes($itemsPath, $originalItems)
    [System.IO.File]::WriteAllBytes($itempoolsPath, $originalItempools)
}

Write-Output 'language entrypoint tests passed'
