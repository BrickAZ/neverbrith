param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputDirectory = 'reports\dante-character'
)

$ErrorActionPreference = 'Stop'
$atlasPath = Join-Path $ModRoot 'resources\gfx\characters\costumes\character_dante.png'
$stagePath = Join-Path $ModRoot 'resources\gfx\ui\stage\playerportrait_dante.png'
$hairPath = Join-Path $ModRoot 'resources\gfx\characters\costumes\costume_dante_hair.png'
$bossNamePath = Join-Path $ModRoot 'resources\gfx\ui\boss\playername_dante.png'
$menuPortraitPath = Join-Path $ModRoot 'content\gfx\dante_character_menu_portrait.png'
$menuNamePath = Join-Path $ModRoot 'content\gfx\dante_character_menu_name.png'
$outputPath = Join-Path $ModRoot $OutputDirectory

foreach ($required in @($atlasPath, $hairPath, $stagePath, $bossNamePath, $menuPortraitPath, $menuNamePath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing Dante asset: $required"
    }
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
Add-Type -AssemblyName System.Drawing

$source = @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class DanteEvidenceRenderer
{
    private static readonly string[] Directions = { "Down", "Left", "Up", "Right" };

    private static void Pixel(Graphics g)
    {
        g.CompositingMode = CompositingMode.SourceCopy;
        g.CompositingQuality = CompositingQuality.HighSpeed;
        g.InterpolationMode = InterpolationMode.NearestNeighbor;
        g.PixelOffsetMode = PixelOffsetMode.Half;
        g.SmoothingMode = SmoothingMode.None;
    }

    private static Bitmap Crop(Bitmap atlas, Rectangle source, bool flipX)
    {
        Bitmap result = new Bitmap(source.Width, source.Height, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(result))
        {
            Pixel(g);
            g.Clear(Color.Transparent);
            g.DrawImage(atlas, new Rectangle(0, 0, source.Width, source.Height), source, GraphicsUnit.Pixel);
        }
        if (flipX) result.RotateFlip(RotateFlipType.RotateNoneFlipX);
        return result;
    }

    private static Bitmap Composite(Bitmap atlas, Bitmap hair, int direction, int phase)
    {
        int bodyY = (direction == 1 || direction == 3) ? 64 : 32;
        int headX;
        if (direction == 0) headX = phase * 32;
        else if (direction == 1 || direction == 3) headX = 64 + phase * 32;
        else headX = 128 + phase * 32;

        bool flip = direction == 1;
        int hairFrame = direction == 0 ? 0 : direction == 1 ? 6 : direction == 2 ? 4 : 2;
        Bitmap body = Crop(atlas, new Rectangle(phase * 32, bodyY, 32, 32), flip);
        Bitmap head = Crop(atlas, new Rectangle(headX, 0, 32, 32), flip);
        Bitmap output = new Bitmap(64, 64, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(output))
        {
            Pixel(g);
            g.Clear(Color.Transparent);
            // Player root at (32, 40). These offsets/pivots come from the official player ANM2.
            g.DrawImageUnscaled(body, 16, 17);
            g.DrawImageUnscaled(head, 16, 7);
            g.CompositingMode = CompositingMode.SourceOver;
            g.DrawImage(hair, new Rectangle(0, -9, 64, 64), new Rectangle((hairFrame + phase) * 64, 0, 64, 64), GraphicsUnit.Pixel);
        }
        body.Dispose();
        head.Dispose();
        return output;
    }

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

    private static void DrawRoom(Graphics g, Rectangle area)
    {
        using (Brush floor = new SolidBrush(Color.FromArgb(255, 91, 66, 56)))
        using (Brush stone = new SolidBrush(Color.FromArgb(255, 57, 48, 47)))
        using (Pen seam = new Pen(Color.FromArgb(255, 113, 83, 66), 1))
        {
            g.FillRectangle(floor, area);
            for (int y = area.Top; y < area.Bottom; y += 16)
                for (int x = area.Left; x < area.Right; x += 24)
                    g.FillRectangle(stone, x + ((y / 16) % 2) * 8, y, 1, 1);
            for (int y = area.Top + 15; y < area.Bottom; y += 16)
                g.DrawLine(seam, area.Left, y, area.Right - 1, y);
        }
    }

    private static void SaveNativeStrip(Bitmap atlas, Bitmap hair, string path)
    {
        using (Bitmap output = new Bitmap(512, 64, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(output))
        {
            Pixel(g);
            g.Clear(Color.Transparent);
            for (int direction = 0; direction < 4; direction++)
                for (int phase = 0; phase < 2; phase++)
                {
                    using (Bitmap frame = Composite(atlas, hair, direction, phase))
                        g.DrawImageUnscaled(frame, (direction * 2 + phase) * 64, 0);
                }
            output.Save(path, ImageFormat.Png);
        }
    }

    private static void SaveBackgroundSheet(Bitmap atlas, Bitmap hair, string path)
    {
        using (Bitmap output = new Bitmap(560, 252, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(output))
        using (Font label = new Font("Arial", 10, FontStyle.Bold, GraphicsUnit.Pixel))
        using (Brush text = new SolidBrush(Color.Black))
        {
            g.Clear(Color.FromArgb(255, 238, 238, 238));
            string[] rows = { "CHECKER", "WHITE", "ROOM-LIKE" };
            for (int row = 0; row < 3; row++)
            {
                int y = 24 + row * 76;
                g.DrawString(rows[row], label, text, 4, y + 24);
                Rectangle background = new Rectangle(48, y, 512, 64);
                if (row == 0) Checker(g, background, 8);
                else if (row == 1) g.FillRectangle(Brushes.White, background);
                else DrawRoom(g, background);
                for (int direction = 0; direction < 4; direction++)
                    for (int phase = 0; phase < 2; phase++)
                    {
                        using (Bitmap frame = Composite(atlas, hair, direction, phase))
                            g.DrawImageUnscaled(frame, 48 + (direction * 2 + phase) * 64, y);
                    }
            }
            for (int direction = 0; direction < 4; direction++)
                g.DrawString(Directions[direction], label, text, 48 + direction * 128 + 45, 6);
            output.Save(path, ImageFormat.Png);
        }
    }

    private static void SaveInspectionSheet(Bitmap atlas, Bitmap hair, string path)
    {
        using (Bitmap output = new Bitmap(1024, 300, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(output))
        using (Font label = new Font("Arial", 16, FontStyle.Bold, GraphicsUnit.Pixel))
        using (Brush text = new SolidBrush(Color.Black))
        {
            g.Clear(Color.FromArgb(255, 232, 232, 232));
            for (int direction = 0; direction < 4; direction++)
            {
                Rectangle background = new Rectangle(direction * 256, 36, 256, 256);
                Checker(g, background, 32);
                g.CompositingMode = CompositingMode.SourceOver;
                g.PixelOffsetMode = PixelOffsetMode.Default;
                g.SmoothingMode = SmoothingMode.AntiAlias;
                g.DrawString(Directions[direction] + " - 4x nearest", label, text, direction * 256 + 52, 10);
                using (Bitmap frame = Composite(atlas, hair, direction, 0))
                {
                    Pixel(g);
                    g.CompositingMode = CompositingMode.SourceOver;
                    g.DrawImage(frame, background, new Rectangle(0, 0, 64, 64), GraphicsUnit.Pixel);
                }
            }
            output.Save(path, ImageFormat.Png);
        }
    }

    private static void SaveSpecialCrops(Bitmap atlas, string path)
    {
        Rectangle[] crops = {
            new Rectangle(0, 128, 64, 64),
            new Rectangle(0, 192, 64, 64),
            new Rectangle(64, 192, 64, 64),
            new Rectangle(128, 192, 64, 64),
            new Rectangle(192, 128, 64, 64),
            new Rectangle(192, 192, 64, 64)
        };
        string[] labels = { "special", "pickup-A", "pickup-B", "pickup-C", "death-A", "death-B" };
        using (Bitmap output = new Bitmap(432, 94, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(output))
        using (Font label = new Font("Arial", 10, FontStyle.Regular, GraphicsUnit.Pixel))
        using (Brush text = new SolidBrush(Color.Black))
        {
            g.Clear(Color.FromArgb(255, 238, 238, 238));
            for (int i = 0; i < crops.Length; i++)
            {
                Rectangle cell = new Rectangle(i * 72, 0, 64, 64);
                Checker(g, cell, 8);
                using (Bitmap crop = Crop(atlas, crops[i], false))
                    g.DrawImageUnscaled(crop, cell.X, cell.Y);
                g.DrawString(labels[i], label, text, i * 72 + 2, 70);
            }
            output.Save(path, ImageFormat.Png);
        }
    }

    private static void DrawAssetAtNative(Graphics g, Bitmap image, int x, int y, string caption, Font font, Brush text)
    {
        Checker(g, new Rectangle(x, y, image.Width, image.Height), 8);
        g.DrawImageUnscaled(image, x, y);
        g.DrawString(caption + " (native " + image.Width + "x" + image.Height + ")", font, text, x, y + image.Height + 6);
    }

    private static void SaveSurfaceOverview(string stagePath, string bossNamePath, string menuPortraitPath, string menuNamePath, string path)
    {
        using (Bitmap stage = new Bitmap(stagePath))
        using (Bitmap boss = new Bitmap(bossNamePath))
        using (Bitmap menuPortrait = new Bitmap(menuPortraitPath))
        using (Bitmap menuName = new Bitmap(menuNamePath))
        using (Bitmap output = new Bitmap(600, 340, PixelFormat.Format32bppArgb))
        using (Graphics g = Graphics.FromImage(output))
        using (Font label = new Font("Arial", 12, FontStyle.Bold, GraphicsUnit.Pixel))
        using (Brush text = new SolidBrush(Color.Black))
        {
            g.Clear(Color.FromArgb(255, 242, 242, 242));
            DrawAssetAtNative(g, stage, 20, 20, "Stage portrait", label, text);
            DrawAssetAtNative(g, boss, 200, 20, "Boss/name surface", label, text);
            DrawAssetAtNative(g, menuPortrait, 20, 220, "Menu portrait", label, text);
            DrawAssetAtNative(g, menuName, 200, 220, "Menu name", label, text);
            output.Save(path, ImageFormat.Png);
        }
    }

    public static void Render(string atlasPath, string hairPath, string stagePath, string bossNamePath, string menuPortraitPath, string menuNamePath, string outputPath)
    {
        Directory.CreateDirectory(outputPath);
        using (Bitmap atlas = new Bitmap(atlasPath))
        using (Bitmap hair = new Bitmap(hairPath))
        {
            try { SaveNativeStrip(atlas, hair, Path.Combine(outputPath, "dante-native-1x-transparent.png")); }
            catch (Exception ex) { throw new Exception("native strip failed", ex); }
            try { SaveBackgroundSheet(atlas, hair, Path.Combine(outputPath, "dante-native-1x-backgrounds.png")); }
            catch (Exception ex) { throw new Exception("background sheet failed", ex); }
            try { SaveInspectionSheet(atlas, hair, Path.Combine(outputPath, "dante-native-4x-inspection.png")); }
            catch (Exception ex) { throw new Exception("inspection sheet failed", ex); }
            try { SaveSpecialCrops(atlas, Path.Combine(outputPath, "dante-special-crops-1x.png")); }
            catch (Exception ex) { throw new Exception("special crops failed", ex); }
        }
        try { SaveSurfaceOverview(stagePath, bossNamePath, menuPortraitPath, menuNamePath,
            Path.Combine(outputPath, "dante-surface-overview.png")); }
        catch (Exception ex) { throw new Exception("surface overview failed", ex); }
    }
}
'@

$drawingAssemblies = @(
    [Drawing.Graphics].Assembly.Location,
    [Drawing.Rectangle].Assembly.Location,
    (Join-Path $PSHOME 'System.Private.Windows.Core.dll')
)
Add-Type -TypeDefinition $source -ReferencedAssemblies $drawingAssemblies
try {
    [DanteEvidenceRenderer]::Render($atlasPath, $hairPath, $stagePath, $bossNamePath, $menuPortraitPath, $menuNamePath, $outputPath)
}
catch {
    throw $_.Exception.ToString()
}
Write-Output "Rendered Dante native-scale evidence to $outputPath"
