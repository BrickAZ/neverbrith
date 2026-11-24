#requires -Version 7.0
param(
    [string]$ValidatorPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1'),
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ValidatorPath = (Resolve-Path -LiteralPath $ValidatorPath).Path
$pwsh = (Get-Process -Id $PID).Path
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('neverbrith strict ' + [guid]::NewGuid().ToString('N'))
$results = [Collections.Generic.List[object]]::new()
$utf8 = [Text.UTF8Encoding]::new($false)
$callback = "function Neverbirth:Tick() end`nNeverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.Tick)"

function Put([string]$RelativePath, [string]$Body) {
    $path = Join-Path $sandbox $RelativePath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [IO.File]::WriteAllText($path, $Body, $utf8)
}
function Fixture([string]$Name, [string]$Main = 'return {}') {
    Put "$Name/main.lua" $Main
    Put "$Name/content/items.xml" '<items />'
    # The real generator is covered by the repository run, not by these scope fixtures.
    Put "$Name/tools/generate-neverbirth-collectibles.ps1" 'param([string]$Root,[switch]$Check); if (-not $Check) { throw "Check mode required" }'
}
function Run([string]$Name, [int]$ExpectedCode, [string[]]$Required = @(), [string[]]$Forbidden = @(), [string[]]$Extra = @()) {
    $arguments = @('-NoProfile', '-File', $ValidatorPath, '-Root', (Join-Path $sandbox $Name)) + $Extra
    $output = (& $pwsh @arguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
    $errors = [Collections.Generic.List[string]]::new()
    if ($code -ne $ExpectedCode) { $errors.Add("Expected exit $ExpectedCode, got $code") }
    foreach ($pattern in $Required) { if ($output -notmatch $pattern) { $errors.Add("Missing pattern: $pattern") } }
    foreach ($pattern in $Forbidden) { if ($output -match $pattern) { $errors.Add("Unexpected pattern: $pattern") } }
    $results.Add([pscustomobject]@{Name=$Name;Passed=($errors.Count -eq 0);ExpectedExitCode=$ExpectedCode;ExitCode=$code;Arguments=$arguments;Errors=@($errors.ToArray());Output=$output})
    Write-Output "$(if ($errors.Count) {'FAIL'} else {'PASS'}) $Name $($errors -join '; ')"
}

try {
    Fixture 'historical-copies' $callback
    foreach ($dir in @('outputs','reports','release','diagnostics','tmp','worktrees','.worktrees','tests','docs')) {
        Put "historical-copies/$dir/main.lua" ($callback + "`nIsaac.GetEntityVariantByName('HistoricalGhost')")
    }
    Put 'historical-copies/unused.lua' $callback
    Run 'historical-copies' 0 @('Lua scope: 1 file') @('WARN ', 'FAIL ', 'HistoricalGhost')

    Fixture 'backup-cannot-supply-handler' 'Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.Tick)'
    Put 'backup-cannot-supply-handler/outputs/old.lua' 'function Neverbirth:Tick() end'
    Run 'backup-cannot-supply-handler' 1 @("missing Neverbirth handler 'Tick'")

    Fixture 'reachable-duplicate' ("include('modules.live')`n" + $callback)
    Put 'reachable-duplicate/modules/live.lua' "include('main')`nNeverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.Tick)"
    Run 'reachable-duplicate' 0 @('Lua scope: 2 files', 'WARN Callback registration is duplicated')

    Fixture 'reachable-missing-handler' "include('modules.live')"
    Put 'reachable-missing-handler/modules/live.lua' 'Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.Absent)'
    Run 'reachable-missing-handler' 1 @("missing Neverbirth handler 'Absent'")

    Fixture 'local-require' "require('modules.live')"
    Put 'local-require/modules/live.lua' 'Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.Absent)'
    Run 'local-require' 1 @("missing Neverbirth handler 'Absent'", 'Lua scope: 2 files')

    Fixture 'active-entity-lookup' "include('modules.live')"
    Put 'active-entity-lookup/modules/live.lua' "Isaac.GetEntityVariantByName('CurrentUnknown')"
    Run 'active-entity-lookup' 0 @("WARN Lua resolves unregistered entity name 'CurrentUnknown'")

    Fixture 'ignored-loader-text' @'
-- include('line_comment')
--[=[ include('block_comment') ]=]
local sample = "include('string_example')"
local long_sample = [==[ include('long_string_example') ]==]
local json = require('json')
return {}
'@
    Run 'ignored-loader-text' 0 @('Lua scope: 1 file', 'External Lua module: json') @('WARN ', 'FAIL ')

    Fixture 'loader-availability-guard' "if include then include('modules.live') end"
    Put 'loader-availability-guard/modules/live.lua' 'return {}'
    Run 'loader-availability-guard' 0 @('Lua scope: 2 files') @('WARN ', 'FAIL ')

    Fixture 'missing-include' "include('missing')"
    Run 'missing-include' 1 @('Loaded Lua file is missing')

    Fixture 'dynamic-include' 'include(moduleName)'
    Run 'dynamic-include' 0 @('WARN .*Dynamic Lua load.*scope is incomplete')

    Fixture 'concatenated-include' "include('modules.' .. suffix)"
    Run 'concatenated-include' 0 @('WARN .*Dynamic Lua load.*scope is incomplete') @('Loaded Lua file is missing')

    Fixture 'unknown-require' "require('external_package')"
    Run 'unknown-require' 0 @('WARN .*Unresolved require.*external_package.*scope is incomplete')

    Fixture 'content-death-animation'
    Put 'content-death-animation/content/items.xml' '<items deathanm2="gfx/UI/death.anm2" />'
    Put 'content-death-animation/content/gfx/UI/death.anm2' '<AnimatedActor />'
    Run 'content-death-animation' 0 @() @('WARN ', 'FAIL ')

    Fixture 'wrong-death-animation-location'
    Put 'wrong-death-animation-location/content/items.xml' '<items deathanm2="gfx/UI/death.anm2" />'
    Put 'wrong-death-animation-location/resources/gfx/UI/death.anm2' '<AnimatedActor />'
    Run 'wrong-death-animation-location' 0 @('WARN Asset path not found.*deathanm2=.*expected content path')

    Fixture 'local-asset'
    Put 'local-asset/content/items.xml' '<items gfxroot="gfx/items/collectibles/"><passive id="1" name="Fixture" gfx="local.png" /></items>'
    Put 'local-asset/resources/gfx/items/collectibles/local.png' 'fixture existence only'
    Run 'local-asset' 0 @() @('WARN ', 'FAIL ')

    Put 'game/isaac-ng.exe' 'fixture marker; never executed'
    Put 'game/resources/gfx/items/collectibles/vanilla.png' 'fixture existence only'
    Put 'game/resources-dlc3/gfx/items/collectibles/dlc.png' 'fixture existence only'
    Fixture 'native-assets'
    Put 'native-assets/content/items.xml' '<items gfxroot="gfx/items/collectibles/"><passive id="1" name="Vanilla" gfx="vanilla.png" /><passive id="2" name="DLC" gfx="dlc.png" /></items>'
    Run 'native-assets' 0 @('INFO Native asset found.*vanilla.png', 'INFO Native asset found.*dlc.png') @('WARN ', 'FAIL ') @('-GameRoot', (Join-Path $sandbox 'game'))

    Fixture 'game/mods/auto-discovery'
    Put 'game/mods/auto-discovery/content/items.xml' '<items gfxroot="gfx/items/collectibles/"><passive id="1" name="Vanilla" gfx="vanilla.png" /></items>'
    Run 'game/mods/auto-discovery' 0 @('INFO Native asset found.*vanilla.png') @('WARN ', 'FAIL ')

    Fixture 'no-game-root'
    Put 'no-game-root/content/items.xml' '<items gfxroot="gfx/items/collectibles/"><passive id="1" name="Vanilla" gfx="vanilla.png" /></items>'
    Run 'no-game-root' 0 @('Game resources unavailable', 'WARN Asset path not found.*native resources not verified')

    Fixture 'missing-native-asset'
    Put 'missing-native-asset/content/items.xml' '<items gfxroot="gfx/items/collectibles/"><passive id="1" name="Missing" gfx="missing.png" /></items>'
    Run 'missing-native-asset' 0 @('WARN Asset path not found.*missing.png') @('INFO Native asset found') @('-GameRoot', (Join-Path $sandbox 'game'))

    Fixture 'invalid-game-root'
    Run 'invalid-game-root' 1 @('FAIL Invalid GameRoot') @() @('-GameRoot', (Join-Path $sandbox 'no-such-game'))

    Fixture 'missing-entry'
    Remove-Item -LiteralPath (Join-Path $sandbox 'missing-entry/main.lua')
    Run 'missing-entry' 1 @('Loaded Lua file is missing.*main.lua')

    Fixture 'independent-snapshot'
    Put 'independent-snapshot/outputs/package/main.lua' ($callback + "`nNeverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.Tick)")
    Put 'independent-snapshot/outputs/package/content/items.xml' '<items />'
    Put 'independent-snapshot/outputs/package/tools/generate-neverbirth-collectibles.ps1' 'param([string]$Root,[switch]$Check)'
    Run 'independent-snapshot/outputs/package' 0 @('WARN Callback registration is duplicated')
} finally {
    $resolved = [IO.Path]::GetFullPath($sandbox)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'neverbrith strict *') {
        if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    } else { throw "Unsafe temporary cleanup path: $resolved" }
}
$failed = @($results | Where-Object { -not $_.Passed }).Count
if ($ReportPath) {
    $target = [IO.Path]::GetFullPath($ReportPath)
    [IO.Directory]::CreateDirectory((Split-Path -Parent $target)) | Out-Null
    [ordered]@{TimestampUtc=[DateTime]::UtcNow.ToString('o');ValidatorPath=$ValidatorPath;ValidatorHash=(Get-FileHash -LiteralPath $ValidatorPath -Algorithm SHA256).Hash;Total=$results.Count;Failed=$failed;InGameVerified=$false;Cases=@($results.ToArray())} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $target -Encoding utf8
}
Write-Output "Strict validator scope tests: $($results.Count - $failed) passed, $failed failed."
if ($failed) { exit 1 }
exit 0
