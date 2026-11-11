#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot "orbit.exe"),
    [string]$InstallDir = (Join-Path $env:ProgramFiles "Worbit"),
    [string]$DataDir = (Join-Path $env:ProgramData "Worbit"),
    [string]$ServiceName = "Orbit",
    [string]$EnvFile,
    [string]$Account,
    [string]$Password,
    [switch]$NoStart
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

function Set-DirectoryAcl {
    param([string]$Path)
    & icacls.exe $Path /inheritance:r /grant:r `
        "*S-1-5-18:(OI)(CI)F" `
        "*S-1-5-32-544:(OI)(CI)F" | Out-Null
    Assert-ExitCode "icacls $Path"
    if ($Account) {
        & icacls.exe $Path /grant:r "${Account}:(OI)(CI)F" | Out-Null
        Assert-ExitCode "icacls $Path /grant $Account"
    }
}

Assert-Administrator

$Source = (Resolve-Path $Source).Path
if (-not (Test-Path $Source)) {
    throw "orbit.exe not found at $Source"
}

New-Item -ItemType Directory -Force $InstallDir, $DataDir | Out-Null
foreach ($dir in @("data", "backups", "logs", "config")) {
    New-Item -ItemType Directory -Force (Join-Path $DataDir $dir) | Out-Null
}

$ConfigPath = Join-Path $DataDir "config/worbit.env"
if ($EnvFile) {
    $EnvFile = (Resolve-Path $EnvFile).Path
    $resolvedConfig = [System.IO.Path]::GetFullPath($ConfigPath)
    if ($EnvFile -ne $resolvedConfig) {
        Copy-Item $EnvFile $ConfigPath -Force
    }
} elseif (-not (Test-Path $ConfigPath)) {
    Copy-Item (Join-Path $PSScriptRoot "worbit.env.example") $ConfigPath
    throw @"
Created $ConfigPath from the example.
Edit ORBIT_PUBLIC_ORIGIN, ORBIT_TRUSTED_PROXIES, the paths, and the app key first.
Generate the app key with:
  $bytes = [byte[]]::new(32); [Security.Cryptography.RandomNumberGenerator]::Fill($bytes); [Convert]::ToBase64String($bytes)
Then rerun install.ps1.
"@
}

Set-DirectoryAcl $InstallDir
Set-DirectoryAcl $DataDir
& icacls.exe $ConfigPath /inheritance:r /grant:r "*S-1-5-18:R" "*S-1-5-32-544:R" | Out-Null
Assert-ExitCode "icacls $ConfigPath"
if ($Account) {
    & icacls.exe $ConfigPath /grant:r "${Account}:R" | Out-Null
    Assert-ExitCode "icacls $ConfigPath /grant $Account"
}

$InstalledExe = Join-Path $InstallDir "orbit.exe"
$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Stopping the existing $ServiceName service"
    if ($existing.Status -ne "Stopped") {
        Stop-Service -Name $ServiceName -Force
        $existing.WaitForStatus("Stopped", [TimeSpan]::FromSeconds(30))
    }
    if (Test-Path $InstalledExe) {
        & $InstalledExe service uninstall --name $ServiceName | Out-Null
        Assert-ExitCode "orbit service uninstall"
    } else {
        & sc.exe delete $ServiceName | Out-Null
        Assert-ExitCode "sc.exe delete $ServiceName"
    }
}

$sourcePath = [System.IO.Path]::GetFullPath($Source)
$installedPath = [System.IO.Path]::GetFullPath($InstalledExe)
if ($sourcePath -ne $installedPath) {
    Copy-Item $sourcePath $installedPath -Force
}

# Make config check and service install see the same file the service will read.
$env:ORBIT_ENV_FILE = $ConfigPath
Write-Host "Validating $ConfigPath"
& $InstalledExe config check
Assert-ExitCode "orbit config check"

Write-Host "Registering the $ServiceName service"
& $InstalledExe service install --name $ServiceName --env-file $ConfigPath
Assert-ExitCode "orbit service install"

if ($Account) {
    if ($Password) {
        & sc.exe config $ServiceName obj= "$Account" password= "$Password" | Out-Null
    } else {
        & sc.exe config $ServiceName obj= "$Account" | Out-Null
    }
    Assert-ExitCode "sc.exe config $ServiceName"
}

if (-not $NoStart) {
    Write-Host "Starting $ServiceName"
    try {
        Start-Service -Name $ServiceName
        (Get-Service -Name $ServiceName).WaitForStatus("Running", [TimeSpan]::FromSeconds(30))
    } catch {
        $log = Join-Path $DataDir "logs/orbit.log"
        if (Test-Path $log) {
            Write-Host "Last log lines from $log"
            Get-Content $log -Tail 100
        }
        throw
    }
}

Write-Host ""
Write-Host "Installed $ServiceName"
Write-Host "  binary: $InstalledExe"
Write-Host "  config: $ConfigPath"
Write-Host "  data:   $DataDir"
Write-Host "  logs:   $(Join-Path $DataDir 'logs/orbit.log')"
Write-Host "  status: sc.exe query $ServiceName"
