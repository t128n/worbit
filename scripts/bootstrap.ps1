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
    if (Test-Path $RepoPath) {
        throw "$RepoPath exists but is not a git checkout; remove it and retry"
    }
    $parent = Split-Path -Parent $RepoPath
    if ($parent) {
        New-Item -ItemType Directory -Force $parent | Out-Null
    }
    Write-Step "Cloning $($lock.Repository)"
    & git clone --filter=blob:none --no-checkout $lock.Repository $RepoPath
    Assert-LastExitCode "git clone"
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
Invoke-Git $RepoPath clean -fdx

$head = (& git -C $RepoPath rev-parse HEAD).Trim()
if ($head -ne $lock.Commit) {
    throw "checkout is at $head, expected $($lock.Commit)"
}

Write-Host "Orbit $($lock.Tag) is ready at $RepoPath"
