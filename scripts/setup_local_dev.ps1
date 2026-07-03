#Requires -Version 5.1
<#
.SYNOPSIS
    First-time local development setup for su-PathComponentArray on Windows.

.DESCRIPTION
    Clones the repository into a fixed local folder, checks out the requested
    branch, and creates the symbolic links that SketchUp 2025 needs in its
    Plugins folder so the extension loads from your working copy.

    This script only touches:
      - the local clone folder you pass via -RepoPath
      - two links inside the SketchUp 2025 Plugins folder
    It never modifies SketchUp's own files or any other repository.

.PARAMETER RepoPath
    Local folder for the clone (the repository root). Default:
    "C:\Users\shuns\.claude\projects\su-PathComponentArray". This is a fixed,
    long-term location chosen to avoid OneDrive-backed Documents. Change it if
    needed, and use the SAME value in update_local_dev.ps1.

.PARAMETER Branch
    Branch to check out. Default: "main" (the mainline; PR #1 for the v0.1 MVP
    is already merged into main).

.PARAMETER RepoUrl
    Git URL to clone from. Default: the su-PathComponentArray GitHub repo.

.PARAMETER PluginsPath
    SketchUp 2025 Plugins folder. Default:
    "$env:APPDATA\SketchUp\SketchUp 2025\SketchUp\Plugins".

.PARAMETER Force
    Replace existing links (or an existing real file/folder) at the link paths.

.EXAMPLE
    .\scripts\setup_local_dev.ps1

.EXAMPLE
    .\scripts\setup_local_dev.ps1 -RepoPath "D:\dev\su-PathComponentArray" -Branch main

.NOTES
    Creating symbolic links on Windows requires either an elevated
    ("Run as administrator") PowerShell, or Developer Mode enabled under
    Settings > Privacy & security > For developers.

    If the script is blocked by the execution policy, run it as:
        powershell -ExecutionPolicy Bypass -File .\scripts\setup_local_dev.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoPath    = 'C:\Users\shuns\.claude\projects\su-PathComponentArray',
    [string]$Branch      = 'main',
    [string]$RepoUrl     = 'https://github.com/airesearchagl-art/su-PathComponentArray.git',
    [string]$PluginsPath = (Join-Path $env:APPDATA 'SketchUp\SketchUp 2025\SketchUp\Plugins'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Names that exist at the repo root and must be linked into the Plugins folder.
$LinkFile   = 'su_path_component_array.rb'
$LinkFolder = 'su_path_component_array'

function Write-Section($text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }
function Write-Ok($text)      { Write-Host "[ OK ] $text"      -ForegroundColor Green }
function Write-Warn2($text)   { Write-Host "[WARN] $text"      -ForegroundColor Yellow }

function Test-SymlinkCapability {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    $devMode = $false
    try {
        $key = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'
        $value = (Get-ItemProperty -Path $key -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction Stop)
        $devMode = ($value.AllowDevelopmentWithoutDevLicense -eq 1)
    } catch {
        $devMode = $false
    }
    return ($isAdmin -or $devMode)
}

function New-DevSymlink {
    param(
        [Parameter(Mandatory)] [string]$LinkPath,
        [Parameter(Mandatory)] [string]$TargetPath
    )
    if (-not (Test-Path -LiteralPath $TargetPath)) {
        throw "Link target not found: $TargetPath"
    }
    if (Test-Path -LiteralPath $LinkPath) {
        $item   = Get-Item -LiteralPath $LinkPath -Force
        $isLink = ($item.LinkType -eq 'SymbolicLink')
        if ($isLink) {
            # Delete the link itself (never follows into the target).
            $item.Delete()
        } elseif ($Force) {
            Remove-Item -LiteralPath $LinkPath -Recurse -Force
        } else {
            Write-Warn2 "Exists and is not a symlink (use -Force to replace): $LinkPath"
            return
        }
    }
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $TargetPath | Out-Null
    Write-Ok "Linked $LinkPath -> $TargetPath"
}

Write-Host 'su-PathComponentArray - local dev setup' -ForegroundColor White

# --- 1. Prerequisites ----------------------------------------------------
Write-Section 'Checking prerequisites'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git was not found on PATH. Install Git for Windows: https://git-scm.com/download/win'
}
Write-Ok 'git found'

if (Test-SymlinkCapability) {
    Write-Ok 'Symbolic-link creation is allowed (admin or Developer Mode).'
} else {
    Write-Warn2 'Symbolic links will likely FAIL to create in this session.'
    Write-Warn2 'Re-run this script from an elevated "Run as administrator" PowerShell,'
    Write-Warn2 'or enable Settings > Privacy & security > For developers > Developer Mode.'
}

# --- 2. Clone or reuse the repository ------------------------------------
Write-Section 'Repository'
if (Test-Path -LiteralPath (Join-Path $RepoPath '.git')) {
    Write-Ok "Existing clone found at $RepoPath (skipping clone)."
} elseif (Test-Path -LiteralPath $RepoPath) {
    $hasContent = (Get-ChildItem -LiteralPath $RepoPath -Force | Measure-Object).Count -gt 0
    if ($hasContent) {
        throw "Folder exists and is not a git clone: $RepoPath. Use an empty folder via -RepoPath or remove it."
    }
    Write-Host "Cloning $RepoUrl -> $RepoPath"
    git clone $RepoUrl $RepoPath
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
} else {
    $parent = Split-Path -Parent $RepoPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Write-Host "Cloning $RepoUrl -> $RepoPath"
    git clone $RepoUrl $RepoPath
    if ($LASTEXITCODE -ne 0) { throw 'git clone failed.' }
}

# --- 3. Check out the requested branch -----------------------------------
Write-Section "Checking out branch '$Branch'"
Push-Location $RepoPath
try {
    git fetch origin --prune
    if ($LASTEXITCODE -ne 0) { throw 'git fetch failed.' }

    git checkout $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "git checkout '$Branch' failed. Does the branch exist on origin?"
    }

    $current = (git rev-parse --abbrev-ref HEAD).Trim()
    Write-Ok "On branch '$current'"
    git log --oneline -1
} finally {
    Pop-Location
}

# --- 4. Create the Plugins symbolic links --------------------------------
Write-Section 'SketchUp Plugins links'
if (-not (Test-Path -LiteralPath $PluginsPath)) {
    Write-Warn2 "Plugins folder not found: $PluginsPath"
    Write-Warn2 'Is SketchUp 2025 installed for this user? Pass -PluginsPath to override.'
    throw 'Aborting: the SketchUp 2025 Plugins folder does not exist.'
}

New-DevSymlink -LinkPath (Join-Path $PluginsPath $LinkFile)   -TargetPath (Join-Path $RepoPath $LinkFile)
New-DevSymlink -LinkPath (Join-Path $PluginsPath $LinkFolder) -TargetPath (Join-Path $RepoPath $LinkFolder)

# --- 5. Done -------------------------------------------------------------
Write-Section 'Done'
Write-Ok 'Local development setup complete.'
Write-Host 'Restart SketchUp 2025 so it loads the extension from your working copy.' -ForegroundColor Yellow
