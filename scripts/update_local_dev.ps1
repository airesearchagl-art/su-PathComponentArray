#Requires -Version 5.1
<#
.SYNOPSIS
    Update an existing local su-PathComponentArray development clone.

.DESCRIPTION
    Shows the current branch, fetches from origin, optionally switches to a
    requested branch, fast-forwards the local branch (git pull), and reminds
    you to restart SketchUp.

    This script does NOT create or modify symbolic links. The links created by
    setup_local_dev.ps1 point at your working copy, so a successful pull is
    enough for SketchUp to pick up the new code after a restart.

.PARAMETER RepoPath
    Local clone folder. Default:
    "C:\Users\shuns\.claude\projects\su-PathComponentArray".
    Use the SAME value you passed to setup_local_dev.ps1.

.PARAMETER Branch
    Branch to switch to before pulling. Default: "main" (normal operation
    tracks mainline after the v0.1 PR was merged). Pass another branch name
    only when you deliberately want to update a work branch.

.EXAMPLE
    .\scripts\update_local_dev.ps1

.EXAMPLE
    .\scripts\update_local_dev.ps1 -Branch main

.NOTES
    If the script is blocked by the execution policy, run it as:
        powershell -ExecutionPolicy Bypass -File .\scripts\update_local_dev.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoPath = 'C:\Users\shuns\.claude\projects\su-PathComponentArray',
    [string]$Branch   = 'main'
)

$ErrorActionPreference = 'Stop'

function Write-Section($text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }
function Write-Ok($text)      { Write-Host "[ OK ] $text"      -ForegroundColor Green }
function Write-Warn2($text)   { Write-Host "[WARN] $text"      -ForegroundColor Yellow }

Write-Host 'su-PathComponentArray - local dev update' -ForegroundColor White

# --- 1. Prerequisites ----------------------------------------------------
Write-Section 'Checking prerequisites'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git was not found on PATH. Install Git for Windows: https://git-scm.com/download/win'
}
if (-not (Test-Path -LiteralPath (Join-Path $RepoPath '.git'))) {
    throw "No git clone found at $RepoPath. Run setup_local_dev.ps1 first (or pass -RepoPath)."
}
Write-Ok "Clone found at $RepoPath"

# --- 2. Update -----------------------------------------------------------
Push-Location $RepoPath
try {
    $current = (git rev-parse --abbrev-ref HEAD).Trim()
    Write-Section 'Current state'
    Write-Host "Current branch: $current"

    git fetch origin --prune
    if ($LASTEXITCODE -ne 0) { throw 'git fetch failed.' }

    if ($Branch -and ($Branch -ne $current)) {
        Write-Section "Switching to branch '$Branch'"
        git checkout $Branch
        if ($LASTEXITCODE -ne 0) { throw "git checkout '$Branch' failed. Does the branch exist on origin?" }
        $current = (git rev-parse --abbrev-ref HEAD).Trim()
        Write-Ok "Now on branch '$current'"
    }

    Write-Section "Pulling latest for '$current'"
    git pull --ff-only origin $current
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 'git pull --ff-only could not fast-forward.'
        Write-Warn2 'You may have local commits/changes or a diverged branch.'
        Write-Warn2 'Resolve manually (commit/stash or rebase), then re-run.'
        throw 'Pull failed.'
    }

    Write-Ok "Updated. Now on '$current':"
    git log --oneline -1
} finally {
    Pop-Location
}

# --- 3. Done -------------------------------------------------------------
Write-Section 'Done'
Write-Host 'Restart SketchUp 2025 to load the updated extension.' -ForegroundColor Yellow
