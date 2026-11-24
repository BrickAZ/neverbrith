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
    @{ Id = 24; Gfx = "fortune_rivalling_heaven_gu.png"; HasSketch = $true },
    @{ Id = 25; Gfx = "UtilityKnife.png"; HasSketch = $true },
    @{ Id = 26; Gfx = "Cleaver.png"; HasSketch = $true },
    @{ Id = 27; Gfx = "Chunyao.png"; HasSketch = $true },
    @{ Id = 28; Gfx = "Musicbox.png"; HasSketch = $true },
    @{ Id = 29; Gfx = "Angelbox.png"; HasSketch = $true },
    @{ Id = 30; Gfx = "Devilbox.png"; HasSketch = $true },
    @{ Id = 31; Gfx = "ds4.png"; HasSketch = $true },
    @{ Id = 32; Gfx = "little_leather_shoes.png"; HasSketch = $true },
    @{ Id = 33; Gfx = "traffic_unboxing.png"; HasSketch = $false },
    @{ Id = 34; Gfx = "traffic_exposure.png"; HasSketch = $false },
    @{ Id = 35; Gfx = "traffic_heat.png"; HasSketch = $false },
    @{ Id = 36; Gfx = "certificate_of_neverbirth.png"; HasSketch = $false },
    @{ Id = 37; Gfx = "saikeissho.png"; HasSketch = $true },
    @{ Id = 38; Gfx = "Everchanging.png"; HasSketch = $true },
    @{ Id = 39; Gfx = "protein_strip.png"; HasSketch = $true },
    @{ Id = 40; Gfx = "energy_kibble.png"; HasSketch = $true },
    @{ Id = 41; Gfx = "lean_can.png"; HasSketch = $true },
    @{ Id = 42; Gfx = "dha_fish_oil.png"; HasSketch = $true },
    @{ Id = 43; Gfx = "dental_chew.png"; HasSketch = $true },
    @{ Id = 44; Gfx = "lucky_liver_bites.png"; HasSketch = $true },
    @{ Id = 45; Gfx = "goat_milk_pudding.png"; HasSketch = $true },
    @{ Id = 46; Gfx = "ace_anti_cheat_blue.png"; HasSketch = $true },
    @{ Id = 47; Gfx = "yins_curse.png"; HasSketch = $true },
    @{ Id = 48; Gfx = "big_dog_bark.png"; HasSketch = $true },
    @{ Id = 49; Gfx = "wind_charge_rod.png"; HasSketch = $true },
    @{ Id = 50; Gfx = "echo_shard.png"; HasSketch = $true },
    @{ Id = 51; Gfx = "revive_my_beloved.png"; HasSketch = $true },
    @{ Id = 52; Gfx = "NightOfTheCowards.png"; HasSketch = $true },
    @{ Id = 53; Gfx = "Annihilation.png"; HasSketch = $true },
    @{ Id = 54; Gfx = "KamikazeSquad.png"; HasSketch = $true },
    @{ Id = 55; Gfx = "Collectibles_025_Breakfast.png"; HasSketch = $true },
    @{ Id = 56; Gfx = "RingOfTheSevenCurses.png"; HasSketch = $true },
    @{ Id = 57; Gfx = "AvadaKedavraMelon.png"; HasSketch = $true },
    @{ Id = 58; Gfx = "healthy_sleep.png"; HasSketch = $true },
    @{ Id = 59; Gfx = "i_am_a_god.png"; HasSketch = $true },
    @{ Id = 60; Gfx = "god_complex.png"; HasSketch = $true },
    @{ Id = 61; Gfx = "divine_left_hand.png"; HasSketch = $true },
    @{ Id = 62; Gfx = "echo_baby.png"; HasSketch = $true },
    @{ Id = 63; Gfx = "bomb_suit.png"; HasSketch = $true },
    @{ Id = 64; Gfx = "blinky.png"; HasSketch = $true }
    @{ Id = 65; Gfx = "drive_glove_v1.png"; HasSketch = $true }
    @{ Id = 66; Gfx = "zangief_360.png"; HasSketch = $true }
    @{ Id = 67; Gfx = "zangief_720.png"; HasSketch = $true }
    @{ Id = 68; Gfx = "motion_wave.png"; HasSketch = $true }
    @{ Id = 69; Gfx = "motion_dp.png"; HasSketch = $true }
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
    if ($uniqueIds.Count -ne $entries.Count -or $entries.Count -ne $expected.Count) {
        throw "$relativePath contains duplicate or untracked collectible ids; update the append-only sketch manifest for new items"
    }
    foreach ($hiddenId in 33, 34, 35, 36) {
        $hiddenEntry = @($entries | Where-Object { [int]$_.id -eq $hiddenId })
        if ($hiddenEntry.Count -ne 1 -or $hiddenEntry[0].hidden -ne "true") {
            throw "$relativePath expected hidden non-pool collectible id=$hiddenId"
        }
    }
    foreach ($entry in $expected | Where-Object { $_.HasSketch }) {
        $visibleEntry = @($entries | Where-Object { [int]$_.id -eq $entry.Id })[0]
        if ($visibleEntry.hidden -eq "true") {
            throw "$relativePath unexpectedly hides visible item id=$($entry.Id)"
        }
    }
    # Native deathanm2 is resolved from content, unlike ordinary resource ANM2 files.
    $nativePath = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $path) $xml.items.deathanm2))
    if (-not (Test-Path -LiteralPath $nativePath -PathType Leaf)) {
        throw "$relativePath native deathanm2 is missing from content: $nativePath"
    }
}

$anm2Path = $nativePath
[xml]$anm2 = [System.IO.File]::ReadAllText($anm2Path, $utf8)
$animation = $anm2.AnimatedActor.Animations.Animation
$frames = @($animation.LayerAnimations.LayerAnimation.Frame)
if ($anm2.AnimatedActor.Animations.DefaultAnimation -ne "icons" -or $animation.Name -ne "icons" -or [int]$animation.FrameNum -ne 800 -or $frames.Count -ne 800) {
    throw "Unexpected NeverbirthDeathItems animation contract"
}

$sheets = @($anm2.AnimatedActor.Content.Spritesheets.Spritesheet)
$layers = @($anm2.AnimatedActor.Content.Layers.Layer)
if ($sheets.Count -ne 1 -or $sheets[0].Id -ne "0" -or $layers.Count -ne 1 -or $layers[0].SpritesheetId -ne "0") {
    throw "Unexpected death portrait spritesheet/layer contract"
}
$atlasPath = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $anm2Path) $sheets[0].Path))
$expectedAtlasPath = [IO.Path]::GetFullPath((Join-Path $rootPath "resources/gfx/UI/NeverbirthDeathItems.png"))
if ($atlasPath -ne $expectedAtlasPath -or -not (Test-Path -LiteralPath $atlasPath -PathType Leaf)) {
    throw "Native deathanm2 does not resolve the project's shared atlas: $atlasPath"
}
$atlas = [System.Drawing.Bitmap]::FromFile($atlasPath)
try {
    if ($atlas.Width -ne 320 -or $atlas.Height -ne 640) {
        throw "Unexpected NeverbirthDeathItems atlas dimensions"
    }
    foreach ($entry in $expected) {
        $frame = $frames[$entry.Id]
        $x = ($entry.Id % 20) * 16
        $y = [math]::Floor($entry.Id / 20) * 16
        if ([int]$frame.XCrop -ne $x -or [int]$frame.YCrop -ne $y -or [int]$frame.Width -ne 16 -or [int]$frame.Height -ne 16 -or [int]$frame.XPivot -ne 8 -or [int]$frame.YPivot -ne 8 -or [int]$frame.XPosition -ne 0 -or [int]$frame.YPosition -ne 0 -or [int]$frame.Delay -ne 1 -or $frame.Visible -ne "true") {
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

$visibleCount = @($expected | Where-Object { $_.HasSketch }).Count
$hiddenCount = @($expected | Where-Object { -not $_.HasSketch }).Count
Write-Output "My Stuff validation passed: $($expected.Count) stable IDs across 3 XML files, $visibleCount visible sketches, $hiddenCount hidden blank cells; native content ANM2 and relative atlas path verified."
