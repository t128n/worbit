#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:WorbitRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path

function Get-WorbitRoot {
    return $script:WorbitRoot
}

function Get-UpstreamConfig {
    $path = Join-Path $script:WorbitRoot "upstream.lock"
    if (-not (Test-Path $path)) {
        throw "missing $path"
    }
    $values = @{}
    foreach ($line in Get-Content $path) {
        if ($line -match '^\s*#') { continue }
        if ($line -match '^\s*([A-Za-z0-9_.-]+)\s*=\s*"([^"]*)"\s*$') {
            $values[$matches[1]] = $matches[2]
        }
    }
    foreach ($required in @("repository", "tag", "commit")) {
        if (-not $values.ContainsKey($required)) {
            throw "upstream.lock has no '$required' value"
        }
    }
    [pscustomobject]@{
        Repository = $values["repository"]
        Tag        = $values["tag"]
        Commit     = $values["commit"]
    }
}

function Get-PatchSeries {
    $path = Join-Path $script:WorbitRoot "patches/series"
    if (-not (Test-Path $path)) {
        throw "missing $path"
    }
    $patches = @()
    foreach ($line in Get-Content $path) {
        $entry = ($line -replace '#.*$', '').Trim()
        if (-not $entry) { continue }
        if ($entry -notlike '*.patch') {
            throw "patches/series entry '$entry' is not a .patch file"
        }
        $patches += $entry
    }
    if ($patches.Count -eq 0) {
        throw "patches/series is empty"
    }
    return $patches
}

function Resolve-OrbitRepo {
    param([string]$RepoPath)

    if (-not $RepoPath) {
        $RepoPath = Join-Path $script:WorbitRoot ".work/orbit"
    }
    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "no Orbit checkout at $RepoPath; run scripts/bootstrap.ps1 first"
    }
    return (Resolve-Path $RepoPath).Path
}

function Assert-LastExitCode {
    param([string]$Operation)

    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE"
    }
}

function Invoke-Git {
    param(
        [string]$Repo,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Arguments
    )

    & git -C $Repo @Arguments
    Assert-LastExitCode "git $($Arguments -join ' ')"
}

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}
