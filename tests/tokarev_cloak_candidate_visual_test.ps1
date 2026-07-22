$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$bodySourcePath = 'E:\Isaac - Repentance\resources\gfx\characters\costumes\costume_216_ceremonialrobes_body.png'
$headSourcePath = 'E:\Isaac - Repentance\resources\gfx\characters\costumes\costume_216_ceremonialrobes_head.png'
$bodyCandidatePath = Join-Path $Root 'resources\gfx\characters\costumes\costume_tokarev_cloak_body_candidate.png'
$headCandidatePath = Join-Path $Root 'resources\gfx\characters\costumes\costume_tokarev_cloak_head_candidate.png'

Add-Type -AssemblyName System.Drawing

function Open-BitmapCopy([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $source = [System.Drawing.Bitmap]::FromStream($stream)
        try {
            return [System.Drawing.Bitmap]::new($source)
        }
        finally {
            $source.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-CandidateContract(
    [string]$Label,
    [string]$SourcePath,
    [string]$CandidatePath,
    [int]$ExpectedWidth,
    [int]$ExpectedHeight,
    [int[]]$AllowedAlpha
) {
    if (-not (Test-Path -LiteralPath $CandidatePath)) {
        throw "$Label candidate is missing: $CandidatePath"
    }

    $source = Open-BitmapCopy $SourcePath
    $candidate = Open-BitmapCopy $CandidatePath
    try {
        if ($candidate.Width -ne $ExpectedWidth -or $candidate.Height -ne $ExpectedHeight) {
            throw "$Label candidate size mismatch: expected ${ExpectedWidth}x${ExpectedHeight}, got $($candidate.Width)x$($candidate.Height)."
        }
        if ($source.Width -ne $candidate.Width -or $source.Height -ne $candidate.Height) {
            throw "$Label source/candidate canvas mismatch."
        }

        $alphaSet = [System.Collections.Generic.HashSet[int]]::new()
        for ($y = 0; $y -lt $candidate.Height; $y++) {
            for ($x = 0; $x -lt $candidate.Width; $x++) {
                $sourcePixel = $source.GetPixel($x, $y)
                $candidatePixel = $candidate.GetPixel($x, $y)
                if ($sourcePixel.A -ne $candidatePixel.A) {
                    throw "$Label alpha drift at ($x,$y): source=$($sourcePixel.A), candidate=$($candidatePixel.A)."
                }
                [void]$alphaSet.Add([int]$candidatePixel.A)
                if ($candidatePixel.A -gt 0 -and $candidatePixel.R -gt ($candidatePixel.G + 12) -and $candidatePixel.R -gt ($candidatePixel.B + 12)) {
                    throw "$Label contains a red-dominant visible pixel at ($x,$y): $($candidatePixel.ToArgb())."
                }
            }
        }

        $actualAlpha = @($alphaSet | Sort-Object)
        $expectedAlpha = @($AllowedAlpha | Sort-Object)
        if (($actualAlpha -join ',') -ne ($expectedAlpha -join ',')) {
            throw "$Label alpha set mismatch: expected $($expectedAlpha -join ','), got $($actualAlpha -join ',')."
        }
    }
    finally {
        $source.Dispose()
        $candidate.Dispose()
    }
}

Assert-CandidateContract 'body' $bodySourcePath $bodyCandidatePath 256 256 @(0, 255)
Assert-CandidateContract 'head' $headSourcePath $headCandidatePath 256 32 @(0, 77, 153, 255)

Write-Output 'Tokarev cloak candidate visual contract passed'
