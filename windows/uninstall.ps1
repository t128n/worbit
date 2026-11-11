#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles "Worbit"),
    [string]$DataDir = (Join-Path $env:ProgramData "Worbit"),
    [string]$ServiceName = "Orbit",
    [switch]$RemoveFiles
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "run this from an elevated PowerShell prompt"
    }
}

function Assert-ExitCode {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE"
    }
}

Assert-Administrator

$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Stopping the $ServiceName service"
    if ($existing.Status -ne "Stopped") {
        Stop-Service -Name $ServiceName -Force
        $existing.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
    $installedExe = Join-Path $InstallDir "orbit.exe"
    if (Test-Path $installedExe) {
        & $installedExe service uninstall --name $ServiceName
        Assert-ExitCode "orbit service uninstall"
    } else {
        & sc.exe delete $ServiceName | Out-Null
        Assert-ExitCode "sc.exe delete $ServiceName"
    }
} else {
    Write-Host "No $ServiceName service is registered"
}

if ($RemoveFiles) {
    foreach ($path in @($InstallDir, $DataDir)) {
        if (Test-Path $path) {
            Write-Host "Removing $path"
            Remove-Item -Recurse -Force $path
        }
    }
} else {
    Write-Host "Kept $DataDir (database, attachments, backups, config, logs)"
    Write-Host "Use -RemoveFiles to delete the install and data directories"
}
