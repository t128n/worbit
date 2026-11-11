#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/common.ps1"

$lock = Get-UpstreamConfig
if (-not $RepoPath) {
    $RepoPath = Join-Path $script:WorbitRoot ".work/orbit"
}

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    $parent = Split-Path -Parent $RepoPath
    if ($parent) {
        New-Item -ItemType Directory -Force $parent | Out-Null
    }
    if (Test-Path $RepoPath) {
        # Swatinem/rust-cache restores .work/orbit/target before this script runs.
        # Initialize the checkout in place so the cached target survives.
        Write-Step "Initializing a checkout in the existing cache directory $RepoPath"
        Invoke-Git $RepoPath init -b main
        Invoke-Git $RepoPath remote add origin $lock.Repository
    } else {
        Write-Step "Cloning $($lock.Repository)"
        & git clone --filter=blob:none --no-checkout $lock.Repository $RepoPath
        Assert-LastExitCode "git clone"
    }
} else {
    Write-Step "Reusing checkout at $RepoPath"
}

# Patch context is LF. Keep Git for Windows from rewriting the checkout.
Invoke-Git $RepoPath config core.autocrlf false

Write-Step "Fetching $($lock.Tag)"
Invoke-Git $RepoPath fetch --force --tags origin

Write-Step "Checking out $($lock.Commit)"
Invoke-Git $RepoPath checkout --detach --force $lock.Commit
Invoke-Git $RepoPath reset --hard $lock.Commit
# Keep ignored build caches (target/, node_modules/, apps/web/dist/) across runs;
# remove only untracked source files such as a previously applied patch.
Invoke-Git $RepoPath clean -fd

$head = (& git -C $RepoPath rev-parse HEAD).Trim()
if ($head -ne $lock.Commit) {
    throw "checkout is at $head, expected $($lock.Commit)"
}

Write-Host "Orbit $($lock.Tag) is ready at $RepoPath"
