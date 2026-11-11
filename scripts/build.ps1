#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoPath,
    [switch]$SkipWeb
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/common.ps1"

$repo = Resolve-OrbitRepo -RepoPath $RepoPath
foreach ($command in @("bun", "cargo")) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "$command is not on PATH"
    }
}

$revision = (& git -C $repo rev-parse --short=12 HEAD).Trim()
Assert-LastExitCode "git rev-parse"
$env:ORBIT_BUILD_REVISION = $revision

Push-Location $repo
try {
    if (-not $SkipWeb) {
        Write-Step "Installing the web workspace"
        & bun install --frozen-lockfile --filter web
        Assert-LastExitCode "bun install"

        Write-Step "Building the web frontend"
        Push-Location (Join-Path $repo "apps/web")
        try {
            & bun run build
            Assert-LastExitCode "bun run build"
        } finally {
            Pop-Location
        }
    }

    Write-Step "Building orbit.exe (revision $revision)"
    & cargo build --locked --release -p orbit-server
    Assert-LastExitCode "cargo build"
} finally {
    Pop-Location
}

$binary = Join-Path $repo "target/release/orbit.exe"
if (-not (Test-Path $binary)) {
    throw "build finished without $binary"
}

& $binary --help | Out-Null
Assert-LastExitCode "orbit.exe --help"

Write-Host "Built $binary"
