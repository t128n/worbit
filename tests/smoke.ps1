#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Binary = (Join-Path $PSScriptRoot "../.work/orbit/target/release/orbit.exe")
)

$ErrorActionPreference = "Stop"

function Assert-ExitCode {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE"
    }
}

if (-not (Test-Path $Binary)) {
    throw "missing $Binary; run scripts/build.ps1 first"
}

Write-Host "==> orbit.exe --help"
& $Binary --help | Out-Null
Assert-ExitCode "orbit.exe --help"

$data = Join-Path ([System.IO.Path]::GetTempPath()) ("worbit-smoke-" + [guid]::NewGuid())
$config = Join-Path $data "worbit.env"
New-Item -ItemType Directory -Force $data | Out-Null
try {
    $bytes = [byte[]]::new(32)
    [Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    $key = [Convert]::ToBase64String($bytes)
    Set-Content (Join-Path $data "app.key") $key -NoNewline
    @"
ORBIT_ENV=development
ORBIT_BIND=127.0.0.1
ORBIT_PORT=18081
ORBIT_DATABASE_PATH=$data\orbit.sqlite
ORBIT_ATTACHMENTS_PATH=$data\attachments
ORBIT_BACKUPS_PATH=$data\backups
ORBIT_APP_KEY_FILE=$data\app.key
ORBIT_LOG_FILE=$data\logs\orbit.log
"@ | Set-Content $config

    Write-Host "==> orbit.exe config check"
    $env:ORBIT_ENV_FILE = $config
    & $Binary config check
    Assert-ExitCode "orbit.exe config check"
} finally {
    Remove-Item Env:ORBIT_ENV_FILE -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
}

Write-Host "Smoke test passed"
