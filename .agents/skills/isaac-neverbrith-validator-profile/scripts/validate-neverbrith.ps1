#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Root = '.',
    [string]$GameRoot
)

$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).ProviderPath
$entry = Join-Path $rootPath 'tools/check-neverbrith.ps1'
$guide = Join-Path $rootPath 'docs/agent/testing.md'
$validator = Join-Path $rootPath 'tools/validators/validate-neverbrith.ps1'

if (-not (Test-Path -LiteralPath $entry -PathType Leaf) -or
    -not (Test-Path -LiteralPath $guide -PathType Leaf) -or
    -not (Test-Path -LiteralPath $validator -PathType Leaf)) {
    throw "Expected a neverbrith checkout with its repository validation tools at: $rootPath"
}

$validatorPath = (Resolve-Path -LiteralPath $validator).ProviderPath
if ($validatorPath -eq $PSCommandPath) {
    throw 'This compatibility script must delegate to the repository strict validator.'
}

$parameters = @{ Root = $rootPath }
if ($PSBoundParameters.ContainsKey('GameRoot')) {
    $parameters.GameRoot = $GameRoot
}

& $validatorPath @parameters
exit $LASTEXITCODE
