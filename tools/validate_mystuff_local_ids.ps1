param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$rootPath = (Resolve-Path $Root).Path
$utf8 = [System.Text.UTF8Encoding]::new($false)
$expected = @(
    @{ Id = 1; Gfx = "P_EssentialBalm.png"; HasSketch = $true },
    @{ Id = 2; Gfx = "Wuhu.png"; HasSketch = $true },
    @{ Id = 3; Gfx = "UncutCord.png"; HasSketch = $true },
    @{ Id = 4; Gfx = "SterilizationCertificate.png"; HasSketch = $true },
    @{ Id = 5; Gfx = "EmptyCradle.png"; HasSketch = $true },
    @{ Id = 6; Gfx = "ShreddedTarot.png"; HasSketch = $true },
    @{ Id = 7; Gfx = "BloodSkullGu.png"; HasSketch = $true },
    @{ Id = 8; Gfx = "BossOrder.png"; HasSketch = $true },
    @{ Id = 9; Gfx = "BetweenDeathAndLife.png"; HasSketch = $true },
    @{ Id = 10; Gfx = "CoinSewnSword.png"; HasSketch = $true },
    @{ Id = 11; Gfx = "CoinFacedMask.png"; HasSketch = $true },
    @{ Id = 12; Gfx = "BlackTaisui.png"; HasSketch = $true },
    @{ Id = 13; Gfx = "BlackTaisuiMeat.png"; HasSketch = $true },
    @{ Id = 14; Gfx = "PurifiedMushroom.png"; HasSketch = $true },
    @{ Id = 15; Gfx = "GoodGirlOfBabylon.png"; HasSketch = $true },
    @{ Id = 16; Gfx = "Condom.png"; HasSketch = $true },
    @{ Id = 17; Gfx = "DebugController.png"; HasSketch = $true },
    @{ Id = 18; Gfx = "StrongLaxative.png"; HasSketch = $true },
    @{ Id = 19; Gfx = "TowerOfBabel.png"; HasSketch = $true },
    @{ Id = 20; Gfx = "collectible_the_moon_is_beautiful.png"; HasSketch = $true },
    @{ Id = 21; Gfx = "BurnAwayResentment.png"; HasSketch = $true },
    @{ Id = 22; Gfx = "Needletick.png"; HasSketch = $true },
    @{ Id = 23; Gfx = "CrazyCoconut.png"; HasSketch = $true },
    @{ Id = 24; Gfx = "fortune_rivalling_heaven_gu.png"; HasSketch = $false },
    @{ Id = 25; Gfx = "UtilityKnife.png"; HasSketch = $true },
    @{ Id = 26; Gfx = "Cleaver.png"; HasSketch = $true },
    @{ Id = 27; Gfx = "Chunyao.png"; HasSketch = $true },
    @{ Id = 28; Gfx = "Musicbox.png"; HasSketch = $true },
    @{ Id = 29; Gfx = "Angelbox.png"; HasSketch = $true },
    @{ Id = 30; Gfx = "Devilbox.png"; HasSketch = $true },
    @{ Id = 31; Gfx = "ds4.png"; HasSketch = $true },
    @{ Id = 32; Gfx = "little_leather_shoes.png"; HasSketch = $true }
)

foreach ($relativePath in "content/items.xml", "content/items.en_us.xml", "content/items.zh_cn.xml") {
    $path = Join-Path $rootPath $relativePath
    [xml]$xml = [System.IO.File]::ReadAllText($path, $utf8)
    if ($xml.items.deathanm2 -ne "gfx/UI/NeverbirthDeathItems.anm2") {
        throw "$relativePath has no Neverbirth deathanm2 declaration"
    }
    $entries = @($xml.items.passive) + @($xml.items.active) + @($xml.items.familiar) | Where-Object { $_ }
    foreach ($entry in $expected) {
        $matches = @($entries | Where-Object { $_.gfx -eq $entry.Gfx })
        if ($matches.Count -ne 1 -or [int]$matches[0].id -ne $entry.Id) {
            throw "$relativePath expected gfx=$($entry.Gfx) id=$($entry.Id)"
        }
    }
    $uniqueIds = @($entries.id | ForEach-Object { [int]$_ } | Select-Object -Unique)
    if ($uniqueIds.Count -ne $entries.Count -or $entries.Count -ne 36) {
        throw "$relativePath contains duplicate or missing collectible ids"
    }
    foreach ($hiddenId in 33, 34, 35, 36) {
        $hiddenEntry = @($entries | Where-Object { [int]$_.id -eq $hiddenId })
        if ($hiddenEntry.Count -ne 1 -or $hiddenEntry[0].hidden -ne "true") {
            throw "$relativePath expected hidden non-pool collectible id=$hiddenId"
        }
    }
}

$anm2Path = Join-Path $rootPath "resources/gfx/UI/NeverbirthDeathItems.anm2"
[xml]$anm2 = [System.IO.File]::ReadAllText($anm2Path, $utf8)
$animation = $anm2.AnimatedActor.Animations.Animation
$frames = @($animation.LayerAnimations.LayerAnimation.Frame)
if ($animation.Name -ne "icons" -or [int]$animation.FrameNum -ne 800 -or $frames.Count -ne 800) {
    throw "Unexpected NeverbirthDeathItems animation contract"
}

$atlas = [System.Drawing.Bitmap]::FromFile((Join-Path $rootPath "resources/gfx/UI/NeverbirthDeathItems.png"))
try {
    if ($atlas.Width -ne 320 -or $atlas.Height -ne 640) {
        throw "Unexpected NeverbirthDeathItems atlas dimensions"
    }
    foreach ($entry in $expected) {
        $frame = $frames[$entry.Id]
        $x = ($entry.Id % 20) * 16
        $y = [math]::Floor($entry.Id / 20) * 16
        if ([int]$frame.XCrop -ne $x -or [int]$frame.YCrop -ne $y) {
            throw "Frame $($entry.Id) does not crop cell $($entry.Id)"
        }
        $hasInk = $false
        for ($pixelY = $y; $pixelY -lt $y + 16 -and -not $hasInk; $pixelY++) {
            for ($pixelX = $x; $pixelX -lt $x + 16; $pixelX++) {
                if ($atlas.GetPixel($pixelX, $pixelY).A -ne 0) { $hasInk = $true; break }
            }
        }
        if ($entry.HasSketch -ne $hasInk) {
            throw "Atlas cell $($entry.Id) ink mismatch"
        }
    }
} finally {
    $atlas.Dispose()
}

Write-Output "My Stuff local-ID validation passed: 31 mapped cells, 1 reserved transparent cell; hidden IDs 33-36 excluded."