# Explicit checker location must still validate the package's own registry bytes.
param([string]$ReportPath)
$ErrorActionPreference='Stop'
$rootPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$temporaryRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$fixturePath=Join-Path $temporaryRoot ('neverbrith-registry-'+[guid]::NewGuid().ToString('N'))
$generator=Join-Path $rootPath 'tools/generate-neverbirth-collectibles.ps1'
$validator=Join-Path $rootPath 'tools/validators/validate-neverbrith.ps1'
$results=@()
function Invoke-Case([string]$Name,[int]$Expected,[string[]]$Extra){
    $output=& pwsh -NoProfile -File $validator -Root $fixturePath @Extra 2>&1
    $actual=$LASTEXITCODE
    $script:results+=@{name=$Name;exitCode=$actual;expected=$Expected;output=($output-join "`n")}
    if($actual-ne $Expected){throw "$Name expected $Expected, got $actual"}
}
try{
    [IO.Directory]::CreateDirectory((Join-Path $fixturePath 'content'))|Out-Null
    Set-Content (Join-Path $fixturePath 'main.lua') 'return {}'
    Set-Content (Join-Path $fixturePath 'content/items.xml') '<items><passive id="1" name="Fixture"/></items>'
    Copy-Item -LiteralPath (Join-Path $fixturePath 'content/items.xml') -Destination (Join-Path $fixturePath 'content/items.en_us.xml')
    Copy-Item -LiteralPath (Join-Path $fixturePath 'content/items.xml') -Destination (Join-Path $fixturePath 'content/items.zh_cn.xml')
    & $generator -Root $fixturePath | Out-Null
    Invoke-Case 'explicit-valid' 0 @('-RegistryGenerator',$generator)
    Invoke-Case 'default-missing-still-fails' 1 @()
    Set-Content (Join-Path $fixturePath 'generated/neverbirth_collectibles.lua') 'return {}'
    Invoke-Case 'tampered-package-registry-fails' 1 @('-RegistryGenerator',$generator)
    Invoke-Case 'explicit-missing-fails' 1 @('-RegistryGenerator',(Join-Path $fixturePath 'missing.ps1'))
}finally{
    if($ReportPath){$results|ConvertTo-Json -Depth 5|Set-Content $ReportPath}
    $resolved=[IO.Path]::GetFullPath($fixturePath)
    if(-not $resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase)-or (Split-Path $resolved -Leaf)-notlike 'neverbrith-registry-*'){throw 'Unsafe fixture cleanup path'}
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
Write-Output "Strict package checker: $($results.Count) counterexamples passed"
