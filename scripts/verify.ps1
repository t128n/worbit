#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/common.ps1"

$repo = Resolve-OrbitRepo -RepoPath $RepoPath
$patches = @(Get-PatchSeries)
$gitDirectory = (& git -C $repo rev-parse --absolute-git-dir).Trim()
Assert-LastExitCode "git rev-parse --absolute-git-dir"

$temporaryIndex = [System.IO.Path]::GetTempFileName()
$realIndex = Join-Path $gitDirectory "index"
if (Test-Path $realIndex) {
    Copy-Item $realIndex $temporaryIndex -Force
}

$previousIndex = $env:GIT_INDEX_FILE
$env:GIT_INDEX_FILE = $temporaryIndex
try {
    # Check the series cumulatively against HEAD, without touching the working tree.
    Invoke-Git $repo read-tree HEAD
    foreach ($name in $patches) {
        $patch = Join-Path $script:WorbitRoot "patches" $name
        if (-not (Test-Path $patch)) {
            throw "patches/series lists $name, but the file does not exist"
        }
        Write-Step "Checking $name"
        & git -C $repo apply --cached --whitespace=nowarn $patch
        Assert-LastExitCode "git apply --check $name"
    }
} finally {
    if ($null -eq $previousIndex) {
        Remove-Item Env:GIT_INDEX_FILE -ErrorAction SilentlyContinue
    } else {
        $env:GIT_INDEX_FILE = $previousIndex
    }
    Remove-Item $temporaryIndex -Force -ErrorAction SilentlyContinue
}

Write-Host "All $($patches.Count) patch(es) apply cleanly to $((& git -C $repo rev-parse --short HEAD).Trim())"
