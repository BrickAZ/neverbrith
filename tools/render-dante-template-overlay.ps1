param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OfficialAtlas = '',
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$ModRoot = [IO.Path]::GetFullPath($ModRoot)
if (-not $OfficialAtlas) {
    $gameRoot = Split-Path -Parent (Split-Path -Parent $ModRoot)
    $OfficialAtlas = Join-Path $gameRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $ModRoot 'reports\dante-character\dante-official-template-overlay.png'
}
$danteAtlas = Join-Path $ModRoot 'resources\gfx\characters\costumes\character_dante.png'
foreach ($path in @($OfficialAtlas, $danteAtlas)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing atlas: $path" }
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null

$source = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class DanteTemplateOverlay
{
    private static void Checker(Graphics g, Rectangle area, int size)
    {
        using (Brush a = new SolidBrush(Color.FromArgb(255, 224, 224, 224)))
        using (Brush b = new SolidBrush(Color.FromArgb(255, 176, 176, 176)))
        {
            for (int y = area.Top; y < area.Bottom; y += size)
                for (int x = area.Left; x < area.Right; x += size)
                    g.FillRectangle((((x - area.Left) / size + (y - area.Top) / size) % 2 == 0) ? a : b,
                        x, y, Math.Min(size, area.Right - x), Math.Min(size, area.Bottom - y));
        }
    }

    private static ImageAttributes Opacity(float alpha)
    {
        ColorMatrix matrix = new ColorMatrix();
        matrix.Matrix33 = alpha;
        ImageAttributes attributes = new ImageAttributes();
        attributes.SetColorMatrix(matrix, ColorMatrixFlag.Default, ColorAdjustType.Bitmap);
        return attributes;
    }

    public static void Render(string officialPath, string dantePath, string outputPath)
    {
        using (Bitmap official = new Bitmap(officialPath))
        using (Bitmap dante = new Bitmap(dantePath))
        {
            if (official.Width != 512 || official.Height != 512 || dante.Width != 512 || dante.Height != 512)
                throw new InvalidOperationException("Both player atlases must be 512x512.");
            using (Bitmap output = new Bitmap(1536, 548, PixelFormat.Format32bppArgb))
            using (Graphics g = Graphics.FromImage(output))
            using (Font label = new Font("Arial", 14, FontStyle.Bold, GraphicsUnit.Pixel))
            using (Brush text = new SolidBrush(Color.Black))
            using (ImageAttributes officialOpacity = Opacity(0.45f))
            using (ImageAttributes danteOpacity = Opacity(0.55f))
            {
                g.Clear(Color.FromArgb(255, 238, 238, 238));
                g.DrawString("Official Isaac template - native 1x", label, text, 120, 9);
                g.DrawString("Dante atlas - native 1x", label, text, 690, 9);
                g.DrawString("Direct overlay: official 45% + Dante 55%", label, text, 1128, 9);
                for (int panel = 0; panel < 3; panel++) Checker(g, new Rectangle(panel * 512, 36, 512, 512), 8);
                g.CompositingMode = CompositingMode.SourceOver;
                g.DrawImageUnscaled(official, 0, 36);
                g.DrawImageUnscaled(dante, 512, 36);
                g.DrawImage(official, new Rectangle(1024, 36, 512, 512), 0, 0, 512, 512, GraphicsUnit.Pixel, officialOpacity);
                g.DrawImage(dante, new Rectangle(1024, 36, 512, 512), 0, 0, 512, 512, GraphicsUnit.Pixel, danteOpacity);
                output.Save(outputPath, ImageFormat.Png);
            }
        }
    }
}
'@

Add-Type -TypeDefinition $source -ReferencedAssemblies System.Drawing
[DanteTemplateOverlay]::Render($OfficialAtlas, $danteAtlas, $OutputPath)
Write-Output "Rendered Dante template overlay to $OutputPath"
