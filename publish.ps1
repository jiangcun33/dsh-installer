param(
  [Parameter(Mandatory=$true)][string]$RepoUrl,
  [string]$Branch = "main"
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

# Need git on PATH (e.g. Git for Windows).
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "git was not found. Install Git for Windows and add it to PATH."
}

# Init a git repository if needed.
if (-not (Test-Path (Join-Path $root ".git"))) {
    git -C $root init -b $Branch
} else {
    git -C $root checkout $Branch 2>$null
}

git -C $root add -A
git -C $root commit -m "Open source: DSH Windows one-click installer" 2>$null

# Point to the GitHub remote and push.
git -C $root remote remove origin 2>$null
git -C $root remote add origin $RepoUrl
git -C $root push -u origin $Branch

Write-Host "[publish] Pushed to $RepoUrl branch $Branch"