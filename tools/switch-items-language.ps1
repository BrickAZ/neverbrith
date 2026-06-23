param(
    [Parameter(Mandatory = $true)]
    [string]$Language
)

$ErrorActionPreference = 'Stop'

$supportedLanguages = @('en_us', 'zh_cn')
if ($supportedLanguages -notcontains $Language) {
    throw "Unsupported language '$Language'. Supported languages: en_us, zh_cn."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$templatePairs = @(
    @{
        Template = Join-Path $repoRoot "content/items.$Language.xml"
        Target = Join-Path $repoRoot 'content/items.xml'
    },
    @{
        Template = Join-Path $repoRoot "content/itempools.$Language.xml"
        Target = Join-Path $repoRoot 'content/itempools.xml'
    }
)

foreach ($pair in $templatePairs) {
    if (-not (Test-Path -LiteralPath $pair.Template)) {
        throw "Language template not found: $($pair.Template)"
    }
}

foreach ($pair in $templatePairs) {
    Copy-Item -LiteralPath $pair.Template -Destination $pair.Target -Force
}

Write-Output "Switched content/items.xml and content/itempools.xml to $Language."
