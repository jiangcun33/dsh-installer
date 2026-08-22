param([switch]$SkipIcon)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$assets = Join-Path $root "assets"
$src = Join-Path $root "src"
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------------------
# 1. Generate all icon sizes from assets/test2.png
# ---------------------------------------------------------------------------
if (-not $SkipIcon) {
    $iconSrc = Join-Path $assets "test2.png"
    if (-not (Test-Path $iconSrc)) { throw "Icon source not found: $iconSrc" }
    $bmp = [System.Drawing.Bitmap]::FromFile($iconSrc)
    $sizes = @(16, 32, 48, 64, 128, 256)
    foreach ($s in $sizes) {
        $nb = New-Object System.Drawing.Bitmap($s, $s)
        $g = [System.Drawing.Graphics]::FromImage($nb)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.DrawImage($bmp, 0, 0, $s, $s)
        $nb.Save((Join-Path $assets "icon-$s.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $nb.Dispose()
    }
    $bmp.Dispose()

    function New-DshIco {
        param([string[]]$IconPngs, [string]$OutPath)
        $count = $IconPngs.Count
        $ms = New-Object System.IO.MemoryStream
        $bw = New-Object System.IO.BinaryWriter($ms)
        $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$count)
        $offset = 6 + 16 * $count
        $sizeList = @(16, 32, 48, 64, 128, 256)
        for ($i = 0; $i -lt $count; $i++) {
            $bytes = [System.IO.File]::ReadAllBytes($IconPngs[$i])
            $s = $sizeList[$i]
            $dim = if ($s -eq 256) { 0 } else { $s }
            $bw.Write([byte]$dim); $bw.Write([byte]$dim)
            $bw.Write([byte]0); $bw.Write([byte]0)
            $bw.Write([uint16]1); $bw.Write([uint16]32)
            $bw.Write([uint32]$bytes.Length); $bw.Write([uint32]$offset)
            $offset += $bytes.Length
        }
        foreach ($f in $IconPngs) {
            $bw.Write([System.IO.File]::ReadAllBytes($f))
        }
        $bw.Flush()
        [System.IO.File]::WriteAllBytes($OutPath, $ms.ToArray())
        $bw.Dispose(); $ms.Dispose()
    }

    $iconPngs = $sizes | ForEach-Object { Join-Path $assets "icon-$_.png" }
    New-DshIco -IconPngs $iconPngs -OutPath (Join-Path $assets "dsh.ico")
    Copy-Item (Join-Path $assets "dsh.ico") (Join-Path $src "dsh.ico") -Force
    Write-Host "[build] Generated dsh.ico from assets/test2.png"
}

# ---------------------------------------------------------------------------
# 2. Compile the C# installer
# ---------------------------------------------------------------------------
$csc = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { throw "csc.exe not found (need .NET Framework 4.x)" }

$out = Join-Path $dist "DSH-Setup.exe"
$ico = Join-Path $assets "dsh.ico"
$installPs1 = Join-Path $src "install.ps1"
$launcher = Join-Path $src "launch-dsh.cmd"
$cs = Join-Path $src "Installer.cs"

$cscArgs = @(
    "/nologo",
    "/target:exe",
    "/out:$out",
    "/win32icon:$ico",
    "/resource:$installPs1,install.ps1",
    "/resource:$launcher,launch-dsh.cmd",
    "/resource:$ico,dsh.ico",
    "$cs"
)
& $csc $cscArgs
if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }

Write-Host "[build] Built $out"