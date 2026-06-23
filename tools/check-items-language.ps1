$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$contentRoot = Join-Path $repoRoot 'content'
$itemsPath = Join-Path $contentRoot 'items.xml'
$itempoolsPath = Join-Path $contentRoot 'itempools.xml'
$supportedLanguages = @('en_us', 'zh_cn')

function Test-SameFileHash {
    param(
        [string]$LeftPath,
        [string]$RightPath
    )

    if (-not (Test-Path -LiteralPath $LeftPath) -or -not (Test-Path -LiteralPath $RightPath)) {
        return $false
    }

    return (Get-FileHash -LiteralPath $LeftPath).Hash -eq (Get-FileHash -LiteralPath $RightPath).Hash
}

$itemsLanguage = $null
$itempoolsLanguage = $null

foreach ($language in $supportedLanguages) {
    if (Test-SameFileHash $itemsPath (Join-Path $contentRoot "items.$language.xml")) {
        $itemsLanguage = $language
    }

    if (Test-SameFileHash $itempoolsPath (Join-Path $contentRoot "itempools.$language.xml")) {
        $itempoolsLanguage = $language
    }
}

if ($itemsLanguage -and $itempoolsLanguage -and $itemsLanguage -eq $itempoolsLanguage) {
    Write-Output $itemsLanguage
} elseif ($itemsLanguage -or $itempoolsLanguage) {
    Write-Output 'mixed'
} else {
    Write-Output 'unknown'
}
