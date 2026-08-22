param([switch]$Silent, [switch]$SkipNpm)
# DeepSeek Harness (dsh) one-click installer
# Installs Node.js (if needed), installs @deepseek-ai/dsh globally, and creates a
# desktop shortcut backed by a black-whale (dsh) icon.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Robust path defaults (may be unset in some non-interactive contexts).
if ([string]::IsNullOrEmpty($env:LOCALAPPDATA)) {
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE "AppData\Local"
}
if ([string]::IsNullOrEmpty($env:APPDATA)) {
    $env:APPDATA = Join-Path $env:USERPROFILE "AppData\Roaming"
}
if ([string]::IsNullOrEmpty($env:ProgramFiles)) {
    $env:ProgramFiles = "C:\Program Files"
}
if ([string]::IsNullOrEmpty(${env:ProgramFiles(x86)})) {
    ${env:ProgramFiles(x86)} = "C:\Program Files (x86)"
}
if ([string]::IsNullOrEmpty($env:ComSpec)) {
    $env:ComSpec = Join-Path $env:WINDIR "System32\cmd.exe"
}
if ([string]::IsNullOrEmpty($env:WINDIR)) {
    $env:WINDIR = "C:\Windows"
}

function Write-Step([string]$msg) { Write-Host "[DSH] $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "[DSH] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "[DSH] $msg" -ForegroundColor Yellow }

$dstDir = Join-Path $env:LOCALAPPDATA "DeepSeekHarness"
$icoSrc = Join-Path $PSScriptRoot "dsh.ico"
$launcherSrc = Join-Path $PSScriptRoot "launch-dsh.cmd"

Write-Step "Installing DeepSeek Harness (dsh)..."

# ---------------------------------------------------------------------------
# 1. Find Node.js
# ---------------------------------------------------------------------------
$node = $null
$nodeCandidates = @(
    "node",
    (Join-Path $env:ProgramFiles "nodejs\node.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "nodejs\node.exe"),
    (Join-Path $env:LOCALAPPDATA "Programs\nodejs\node.exe"),
    (Join-Path $env:LOCALAPPDATA "nodejs\node.exe")
)
foreach ($c in $nodeCandidates) {
    if ($c -eq "node") {
        $cmd = Get-Command node -ErrorAction SilentlyContinue
        if ($cmd) { $node = $cmd.Source; break }
    } elseif (Test-Path $c) {
        $node = $c; break
    }
}

if (-not $node) {
    Write-Warn "Node.js was not found. Downloading the latest Node.js LTS (x64) from the npmmirror mirror and installing silently..."

    # Use the npmmirror (Taobao) CDN so Node.js downloads are fast and never
    # hang on the default (often blocked) official source.
    $nodeMirror = "https://cdn.npmmirror.com/binaries/node"
    $fallbackVer = "v24.19.0"
    $nodeVer = $fallbackVer
    try {
        $nodeIndex = Invoke-RestMethod -Uri "$nodeMirror/index.json" -UseBasicParsing -TimeoutSec 30
        $latestLts = $nodeIndex | Where-Object { $_.lts } | Select-Object -First 1
        if ($latestLts -and $latestLts.version) { $nodeVer = $latestLts.version }
        Write-Ok "Resolved latest Node.js LTS: $nodeVer"
    } catch {
        Write-Warn "Could not resolve the latest Node.js version from npmmirror; falling back to $fallbackVer."
    }

    $nodeUrl = "$nodeMirror/$nodeVer/node-$nodeVer-x64.msi"
    $msi = Join-Path $env:TEMP "node-$nodeVer-x64.msi"
    try {
        Invoke-WebRequest -Uri $nodeUrl -OutFile $msi -UseBasicParsing
        Write-Ok "Downloaded Node.js installer from $nodeMirror."
    } catch {
        Write-Warn "Could not download Node.js automatically. Please install it manually and run this installer again."
        Read-Host "Press Enter to exit"
        exit 1
    }
    $p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart ADDLOCAL=ALL" -Wait -PassThru
    Remove-Item $msi -Force -ErrorAction SilentlyContinue
    if ($p.ExitCode -ne 0) {
        Write-Warn "Node.js installation failed (exit code $($p.ExitCode))."
        Read-Host "Press Enter to exit"
        exit 1
    }
    $node = Join-Path $env:ProgramFiles "nodejs\node.exe"
    if (-not (Test-Path $node)) { $node = Join-Path $env:LOCALAPPDATA "Programs\nodejs\node.exe" }
}

Write-Ok "Using Node.js: $node"

# ---------------------------------------------------------------------------
# 2. Make sure node/npm are on PATH (user level)
# ---------------------------------------------------------------------------
$nodeDir = Split-Path $node -Parent
$npmDir = Join-Path $env:APPDATA "npm"

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$changed = $false
foreach ($p in @($nodeDir, $npmDir)) {
    if ($p -and ($userPath -notlike "*$p*")) {
        $userPath = "$userPath;$p"
        $changed = $true
    }
}
if ($changed) {
    [Environment]::SetEnvironmentVariable("Path", $userPath, "User")
    Write-Ok "Updated user PATH with Node/npm directories."
}

# Refresh current process PATH so npm is usable below
$env:Path = [Environment]::GetEnvironmentVariable("Path", "User") + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine")

# ---------------------------------------------------------------------------
# 3. Install / update @deepseek-ai/dsh
# ---------------------------------------------------------------------------
$npm = $null
foreach ($c in @("npm.cmd", "npm")) {
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) { $npm = $cmd.Source; break }
}
if (-not $npm) {
    $npm = Join-Path $nodeDir "npm.cmd"
}
if (-not (Test-Path $npm) -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Warn "npm.cmd wasn't found; verify the Node.js installation."
    Read-Host "Press Enter to exit"
    exit 1
}

if (-not $SkipNpm) {
    $dshShim = Join-Path $npmDir "dsh.cmd"
    $haveDsh = Test-Path $dshShim
    if (-not $haveDsh) {
        $haveDsh = [bool](Get-Command dsh -ErrorAction SilentlyContinue)
    }

    if ($haveDsh) {
        Write-Warn "dsh is already installed; refreshing to the latest version..."
    } else {
        Write-Step "Installing @deepseek-ai/dsh globally (this may take a few minutes)..."
    }

    # Use the npmmirror registry so package downloads never hang on the default
    # (often slow/blocked) registry. Persist it for the user and also pass it
    # explicitly for this exact install.
    $npmRegistry = "https://registry.npmmirror.com"
    & $npm "config" "set" "registry" $npmRegistry
    & $npm "install" "-g" "@deepseek-ai/dsh" "--registry=$npmRegistry"
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "npm install failed. Check your internet connection (mirror: $npmRegistry) and try again."
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Ok "@deepseek-ai/dsh installed/updated (registry: $npmRegistry)."
} else {
    Write-Step "Skipping npm install (dsh must already be present)."
}

# ---------------------------------------------------------------------------
# 4. Copy launcher + icon into the app folder
# ---------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
Copy-Item $launcherSrc (Join-Path $dstDir "launch-dsh.cmd") -Force
Copy-Item $icoSrc (Join-Path $dstDir "dsh.ico") -Force
Write-Ok "Copied launcher and icon to $dstDir"

# ---------------------------------------------------------------------------
# 5. Create desktop shortcut (black whale icon)
# ---------------------------------------------------------------------------
$desktop = [Environment]::GetFolderPath("Desktop")
$launcher = Join-Path $dstDir "launch-dsh.cmd"
$ico = Join-Path $dstDir "dsh.ico"
$shortcutPath = Join-Path $desktop "DeepSeek Harness.lnk"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = "$env:ComSpec"
$shortcut.Arguments = "/c `"`"$launcher`"`""
$shortcut.WorkingDirectory = $env:USERPROFILE
$shortcut.IconLocation = "$ico,0"
$shortcut.Description = "DeepSeek Harness (dsh) - one-click launch"
$shortcut.Save()
Write-Ok "Desktop shortcut created: $shortcutPath"

# Optional Start Menu shortcut
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
if (Test-Path $startMenu) {
    $smShortcut = $shell.CreateShortcut((Join-Path $startMenu "DeepSeek Harness.lnk"))
    $smShortcut.TargetPath = "$env:ComSpec"
    $smShortcut.Arguments = "/c `"`"$launcher`"`""
    $smShortcut.WorkingDirectory = $env:USERPROFILE
    $smShortcut.IconLocation = "$ico,0"
    $smShortcut.Description = "DeepSeek Harness (dsh) - one-click launch"
    $smShortcut.Save()
    Write-Ok "Start menu shortcut created."
}

# ---------------------------------------------------------------------------
# 6. Done
# ---------------------------------------------------------------------------
Write-Ok "DeepSeek Harness is ready. Double-click 'DeepSeek Harness' on the desktop to start."
if (-not $Silent) { Read-Host "Press Enter to close" }
