#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoPath,
    [switch]$Reverse,
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot/lib/common.ps1"

$repo = Resolve-OrbitRepo -RepoPath $RepoPath
$patches = @(Get-PatchSeries)

if (-not $SkipVerify) {
    & (Join-Path $PSScriptRoot "verify.ps1") -RepoPath $repo
}

if ($Reverse) {
    [array]::Reverse($patches)
}

foreach ($name in $patches) {
    $patch = Join-Path $script:WorbitRoot "patches" $name
    $mode = if ($Reverse) { "Reversing" } else { "Applying" }
    Write-Step "$mode $name"
    if ($Reverse) {
        & git -C $repo apply --reverse --whitespace=nowarn $patch
        Assert-LastExitCode "git apply --reverse $name"
    } else {
        & git -C $repo apply --whitespace=nowarn $patch
        Assert-LastExitCode "git apply $name"
    }
}

Write-Host "Patch series applied to $repo"
