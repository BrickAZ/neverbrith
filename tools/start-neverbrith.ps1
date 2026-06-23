param(
    [string]$Language,
    [switch]$NoLaunch,
    [string]$GameRoot,
    [string]$ModRoot
)

$ErrorActionPreference = 'Stop'

$supportedLanguages = @('en_us', 'zh_cn')

function Resolve-LanguageFromSetting {
    param([string]$RawLanguage)

    $normalized = ($RawLanguage -replace '\s+', '').ToLowerInvariant()
    switch ($normalized) {
        { $_ -in @('en', 'enus', 'english') } { return 'en_us' }
        { $_ -in @('zh', 'zhcn', 'chinese', 'chinesesimple', 'chinesesimplified', 'simplifiedchinese', 'schinese') } { return 'zh_cn' }
        default { return $null }
    }
}

function Assert-SupportedLanguage {
    param([string]$LanguageToCheck)

    if ($supportedLanguages -notcontains $LanguageToCheck) {
        throw "Unsupported language '$LanguageToCheck'. Supported languages: en_us, zh_cn."
    }
}

$scriptRoot = $PSScriptRoot
$repoRoot = if ($ModRoot) {
    (Resolve-Path -LiteralPath $ModRoot).Path
} else {
    Split-Path -Parent $scriptRoot
}

$detectedGameRoot = if ($GameRoot) {
    (Resolve-Path -LiteralPath $GameRoot).Path
} else {
    Split-Path -Parent (Split-Path -Parent $repoRoot)
}

if ([string]::IsNullOrWhiteSpace($Language)) {
    $languageSettingPath = Join-Path $detectedGameRoot 'settings/language.txt'
    if (Test-Path -LiteralPath $languageSettingPath) {
        $Language = Resolve-LanguageFromSetting (Get-Content -Raw -LiteralPath $languageSettingPath)
    }

    if ([string]::IsNullOrWhiteSpace($Language)) {
        $Language = 'en_us'
        Write-Output 'Could not detect supported game language; falling back to en_us.'
    }
}

Assert-SupportedLanguage $Language

$switchScriptPath = Join-Path $repoRoot 'tools/switch-items-language.ps1'
$checkScriptPath = Join-Path $repoRoot 'tools/check-items-language.ps1'

if (-not (Test-Path -LiteralPath $switchScriptPath)) {
    throw "Language switch script not found: $switchScriptPath"
}
if (-not (Test-Path -LiteralPath $checkScriptPath)) {
    throw "Language check script not found: $checkScriptPath"
}

& $switchScriptPath -Language $Language | Out-Null
$currentLanguage = (& $checkScriptPath | Out-String).Trim()

if ($currentLanguage -ne $Language) {
    throw "Language synchronization failed. Expected '$Language', got '$currentLanguage'. The game was not launched."
}

Write-Output "Language synchronized: $Language"

if ($NoLaunch) {
    Write-Output 'NoLaunch set; game was not launched.'
    exit 0
}

$gameExecutable = Join-Path $detectedGameRoot 'isaac-ng.exe'
if (-not (Test-Path -LiteralPath $gameExecutable)) {
    throw "Game executable not found: $gameExecutable"
}

Start-Process -FilePath $gameExecutable -WorkingDirectory $detectedGameRoot
Write-Output "Started game: $gameExecutable"
