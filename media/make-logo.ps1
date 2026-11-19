# Draws the Damage Numbers logo: a big gold hit with smaller ones rising and fading
# above it like a combat text stream, on a dusk gradient (Daylight UI's plum into
# the plugin's orange). Writes logo-1024.png and logo-400.png here, and icon.png (64x64)
# next to the addon's files.
Add-Type -AssemblyName System.Drawing
$out = $PSScriptRoot
$addon = Split-Path $PSScriptRoot -Parent

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}
function C([string]$hex, [int]$a = 255) {
    return [System.Drawing.Color]::FromArgb($a, [Convert]::ToInt32($hex.Substring(0,2),16),
        [Convert]::ToInt32($hex.Substring(2,2),16), [Convert]::ToInt32($hex.Substring(4,2),16))
}
function Font([float]$size) {
    foreach ($name in "Segoe UI Black", "Arial Black", "Impact", "Arial") {
        $f = New-Object System.Drawing.Font $name, $size, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        if ($f.Name -eq $name) { return $f }
    }
    return $f
}
# Text as a path, centred on (cx, cy), so it can be outlined and filled.
function TextPath([string]$text, [float]$size, [float]$cx, [float]$cy) {
    $f = Font $size
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fmt = New-Object System.Drawing.StringFormat
    $fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
    $p.AddString($text, $f.FontFamily, [int]$f.Style, $size, (New-Object System.Drawing.PointF $cx, $cy), $fmt)
    $b = $p.GetBounds()
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $m.Translate(($cx - ($b.X + $b.Width / 2)), ($cy - ($b.Y + $b.Height / 2)))
    $p.Transform($m)
    return $p
}
function Number($g, [string]$text, [float]$size, [float]$cx, [float]$cy, [string]$fill, [int]$alpha, [float]$outline) {
    $p = TextPath $text $size $cx $cy
    $pen = New-Object System.Drawing.Pen (C "2a1440" $alpha), $outline
    $pen.LineJoin = 'Round'
    $g.DrawPath($pen, $p)
    $g.FillPath((New-Object System.Drawing.SolidBrush (C $fill $alpha)), $p)
}

$S = 1024
$bmp = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.PixelOffsetMode = 'HighQuality'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::Transparent)

# Background tile: dusk gradient, plum to orange.
$bg = RoundRect 0 0 $S $S 200
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0,0), (New-Object System.Drawing.Point $S,$S), (C "4b2a7a"), (C "ff9e4d")
$blend = New-Object System.Drawing.Drawing2D.ColorBlend 3
$blend.Colors = @((C "3a2266"), (C "8a4a8c"), (C "f0904a")); $blend.Positions = @(0.0, 0.5, 1.0)
$grad.InterpolationColors = $blend
$g.FillPath($grad, $bg)

# Soft sun glow, top right.
$glow = New-Object System.Drawing.Drawing2D.GraphicsPath
$glow.AddEllipse(560, -120, 600, 600)
$pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glow
$pg.CenterColor = (C "ffd89a" 110); $pg.SurroundColors = @((C "ffd89a" 0))
$g.SetClip($bg); $g.FillPath($pg, $glow); $g.ResetClip()

# The stream: hits rising and fading, the newest one big at the bottom.
Number $g "42"  130 600 200 "ffffff" 110 14
Number $g "317" 175 560 380 "ffffff" 185 20

# Warm glow behind the newest hit.
$bx = 512; $by = 650
$halo = New-Object System.Drawing.Drawing2D.GraphicsPath
$halo.AddEllipse(($bx - 400), ($by - 230), 800, 460)
$hg = New-Object System.Drawing.Drawing2D.PathGradientBrush $halo
$hg.CenterColor = (C "ffc46b" 150); $hg.SurroundColors = @((C "ffc46b" 0))
$g.SetClip($bg); $g.FillPath($hg, $halo); $g.ResetClip()

# The newest hit: drop shadow, plum outline, gold-to-orange fill.
$big = TextPath "1386!" 290 $bx $by
$sm = New-Object System.Drawing.Drawing2D.Matrix; $sm.Translate(10, 18)
$shadow = $big.Clone(); $shadow.Transform($sm)
$g.FillPath((New-Object System.Drawing.SolidBrush (C "1a0f2e" 90)), $shadow)
$pen = New-Object System.Drawing.Pen (C "2a1440"), 36
$pen.LineJoin = 'Round'
$g.DrawPath($pen, $big)
$b = $big.GetBounds()
$fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF 0, $b.Top), (New-Object System.Drawing.PointF 0, $b.Bottom), (C "fff4d6"), (C "ff9e4d")
$g.FillPath($fill, $big)

$g.Dispose()
$bmp.Save((Join-Path $out "logo-1024.png"), [System.Drawing.Imaging.ImageFormat]::Png)

function Shrink($src, [int]$size, [string]$path) {
    $small = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $sg = [System.Drawing.Graphics]::FromImage($small)
    $sg.InterpolationMode = 'HighQualityBicubic'; $sg.SmoothingMode = 'AntiAlias'; $sg.PixelOffsetMode = 'HighQuality'
    $sg.DrawImage($src, 0, 0, $size, $size); $sg.Dispose()
    $small.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $small.Dispose()
}
Shrink $bmp 400 (Join-Path $out "logo-400.png")
Shrink $bmp 64 (Join-Path $addon "icon.png")
$bmp.Dispose()
Write-Host "Wrote logo-1024.png, logo-400.png and icon.png"
