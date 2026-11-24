param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$rootPath = [IO.Path]::GetFullPath($Root)
$validator = Join-Path $rootPath 'tools/validate_mystuff_local_ids.ps1'
$fixtureBase = [IO.Path]::GetFullPath((Join-Path $rootPath 'tmp'))
$fixture = [IO.Path]::GetFullPath((Join-Path $fixtureBase ('mystuff-contract-' + [guid]::NewGuid().ToString('N'))))
if (-not $fixture.StartsWith($fixtureBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped the project tmp directory' }
function Assert-Rejected([string]$Reason) {
    $caught = $false
    try { & $validator -Root $fixture | Out-Null }
    catch {
        if (-not $_.Exception.Message.Contains($Reason)) { throw }
        $caught = $true
    }
    if (-not $caught) { throw "Validator accepted a broken fixture: $Reason" }
}
try {
    foreach ($relative in @('content/items.xml','content/items.en_us.xml','content/items.zh_cn.xml','content/gfx/UI/NeverbirthDeathItems.anm2','resources/gfx/UI/NeverbirthDeathItems.png')) {
        $destination = Join-Path $fixture $relative
        [IO.Directory]::CreateDirectory((Split-Path -Parent $destination)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $rootPath $relative) -Destination $destination
    }
    & $validator -Root $fixture
    $native = Join-Path $fixture 'content/gfx/UI/NeverbirthDeathItems.anm2'
    $wrongRoot = Join-Path $fixture 'resources/gfx/UI/NeverbirthDeathItems.anm2'
    Move-Item -LiteralPath $native -Destination $wrongRoot
    Assert-Rejected 'native deathanm2 is missing from content'
    Move-Item -LiteralPath $wrongRoot -Destination $native

    $originalAnm2 = [IO.File]::ReadAllText($native)
    [IO.File]::WriteAllText($native, $originalAnm2.Replace('../../../resources/gfx/UI/NeverbirthDeathItems.png', '../NeverbirthDeathItems.png'))
    Assert-Rejected "does not resolve the project's shared atlas"
    [IO.File]::WriteAllText($native, $originalAnm2)

    # The newest item must be checked too; the old validator stopped at ID 32.
    $atlasPath = Join-Path $fixture 'resources/gfx/UI/NeverbirthDeathItems.png'
    $loaded = [Drawing.Bitmap]::FromFile($atlasPath)
    $atlas = $loaded.Clone([Drawing.Rectangle]::new(0,0,$loaded.Width,$loaded.Height), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $loaded.Dispose()
    try {
        for ($y=32;$y -lt 48;$y++){for($x=304;$x -lt 320;$x++){$atlas.SetPixel($x,$y,[Drawing.Color]::Transparent)}}
        $atlas.Save((Join-Path $fixture 'blank-newest.png'),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $atlas.Dispose() }
    Copy-Item -LiteralPath (Join-Path $fixture 'blank-newest.png') -Destination $atlasPath -Force
    Assert-Rejected 'Atlas cell 59 ink mismatch'
    Write-Output 'My Stuff resource regression checks passed: rejects resources-only entrypoint, broken relative PNG path, and an empty newest visible item.'
} finally {
    if ((Test-Path -LiteralPath $fixture) -and $fixture.StartsWith($fixtureBase + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
