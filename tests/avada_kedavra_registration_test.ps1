$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$names = @{'items.xml'='Avada Kedavra'; 'items.en_us.xml'='Avada Kedavra'; 'items.zh_cn.xml'='阿瓦达啃大瓜'}
foreach ($file in $names.Keys) {
    [xml]$xml = Get-Content -Raw -LiteralPath "content/$file"
    $item = @($xml.items.passive | Where-Object { $_.id -eq '57' })
    if ($item.Count -ne 1 -or $item[0].name -cne $names[$file] -or $item[0].quality -ne '0') { throw "Wrong registration: $file" }
    if ($item[0].gfx -cne 'AvadaKedavraMelon.png') { throw "Wrong graphic: $file" }
    if ($item[0].cache -cne 'damage firedelay tearflag') { throw "Missing damage/firedelay/tearflag cache invalidation: $file" }
    if ($item[0].HasAttribute('maxcharges')) { throw 'Passive item must not be registered as active' }
}
$pools = @{
    'content/itempools.en_us.xml'='Avada Kedavra'
    'content/itempools.xml'='Avada Kedavra'
    'content/itempools.zh_cn.xml'='阿瓦达啃大瓜'
}
foreach ($path in $pools.Keys) {
    [xml]$poolXml = Get-Content -Raw -LiteralPath $path
    $entries = @($poolXml.SelectNodes('/ItemPools/Pool/Item') | Where-Object { $_.Name -ceq $pools[$path] })
    if ($entries.Count -ne 2) { throw "Expected exactly two approved pool entries: $path" }
    foreach ($poolName in @('treasure', 'shop')) {
        $pool = @($poolXml.ItemPools.Pool | Where-Object { $_.Name -ceq $poolName })
        $entry = @($pool[0].SelectNodes('Item') | Where-Object { $_.Name -ceq $pools[$path] })
        if ($entry.Count -ne 1 -or $entry[0].Weight -ne '0.1' -or $entry[0].DecreaseBy -ne '1' -or $entry[0].RemoveOn -ne '0.1') {
            throw "Wrong approved pool entry: $path / $poolName"
        }
    }
}
Add-Type -AssemblyName System.Drawing
$path = (Resolve-Path 'resources/gfx/Items/Collectibles/AvadaKedavraMelon.png').Path
$bmp = [Drawing.Bitmap]::FromFile($path)
try {
    if ($bmp.Width -ne 32 -or $bmp.Height -ne 32) { throw 'Wrong icon size' }
    $opaque=0; $clear=0; $semi=0
    for($y=0;$y -lt 32;$y++) { for($x=0;$x -lt 32;$x++) {
        $a=$bmp.GetPixel($x,$y).A
        if ($a -eq 255) {$opaque++} elseif ($a -eq 0) {$clear++} else {$semi++}
        if (($x -eq 0 -or $y -eq 0 -or $x -eq 31 -or $y -eq 31) -and $a -ne 0) { throw 'Opaque icon outer edge' }
    }}
    if ($opaque -ne 331 -or $clear -ne 693 -or $semi -ne 0) { throw 'Icon alpha differs from artist handoff' }
} finally { $bmp.Dispose() }
Write-Output 'avada_kedavra_registration_test: PASS (XML id 57, quality 0, locales, treasure/shop weight 0.1, icon alpha)'
