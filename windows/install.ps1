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

function Set-FileAclReadOnly {
    param([string]$Path)
    & icacls.exe $Path /inheritance:r /grant:r "*S-1-5-18:R" "*S-1-5-32-544:R" | Out-Null
    Assert-ExitCode "icacls $Path"
    if ($Account) {
        & icacls.exe $Path /grant:r "${Account}:R" | Out-Null
        Assert-ExitCode "icacls $Path /grant $Account"
    }
}

# Reads one setting from the env file with the same rules Orbit uses: KEY=VALUE,
# an optional leading `export `, and matching single or double quotes around the
# value are stripped. The last occurrence wins. Returns $null when the setting
# is absent.
function Get-EnvFileValue {
    param(
        [string]$Path,
        [string]$Name
    )
    $value = $null
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $line = $raw.Trim().TrimStart([char]0xFEFF)
        if (-not $line -or $line.StartsWith("#")) {
            continue
        }
        if ($line.StartsWith("export ")) {
            $line = $line.Substring(7).TrimStart()
        }
        $separator = $line.IndexOf("=")
        if ($separator -lt 0) {
            continue
        }
        if ($line.Substring(0, $separator).Trim() -ne $Name) {
            continue
        }
        $value = $line.Substring($separator + 1).Trim()
        if ($value.Length -ge 2) {
            $first = $value.Substring(0, 1)
            $last = $value.Substring($value.Length - 1, 1)
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }
    }
    return $value
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

Set-DirectoryAcl $InstallDir
Set-DirectoryAcl $DataDir

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
Edit ORBIT_PUBLIC_ORIGIN, ORBIT_TRUSTED_PROXIES, and the paths, then rerun install.ps1.
The app key is generated automatically on the next run if it is missing.
"@
}

# Orbit refuses to start without an app key. Create the configured file on the
# first install so setup does not need a separate key-generation step.
$AppKeyPath = Get-EnvFileValue -Path $ConfigPath -Name "ORBIT_APP_KEY_FILE"
$AppKeyValue = Get-EnvFileValue -Path $ConfigPath -Name "ORBIT_APP_KEY"
$AppKeyFileConfigured = $null -ne $AppKeyPath
if (-not $AppKeyFileConfigured) {
    $AppKeyPath = Join-Path $DataDir "config/app.key"
}
if ($null -eq $AppKeyValue) {
    if ($AppKeyPath -eq "") {
        throw "ORBIT_APP_KEY_FILE is set but empty in $ConfigPath"
    }
    if (-not [System.IO.Path]::IsPathRooted($AppKeyPath)) {
        throw "ORBIT_APP_KEY_FILE must be an absolute path: $AppKeyPath"
    }
    $AppKeyPath = [System.IO.Path]::GetFullPath($AppKeyPath)
    if (-not (Test-Path -LiteralPath $AppKeyPath)) {
        New-Item -ItemType Directory -Force (Split-Path -Parent $AppKeyPath) | Out-Null
        $bytes = [byte[]]::new(32)
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $rng.GetBytes($bytes)
        } finally {
            $rng.Dispose()
        }
        [System.IO.File]::WriteAllText(
            $AppKeyPath,
            [Convert]::ToBase64String($bytes),
            [System.Text.Encoding]::ASCII)
        Set-FileAclReadOnly $AppKeyPath
        Write-Host "Generated app key: $AppKeyPath"
        Write-Host "Back it up now: without it, saved secrets cannot be decrypted."
    }
    if (-not $AppKeyFileConfigured) {
        # The env file did not name a key file, so point it at the generated one.
        $contents = [System.IO.File]::ReadAllText($ConfigPath)
        if ($contents.Length -gt 0 -and -not ($contents.EndsWith("`n") -or $contents.EndsWith("`r"))) {
            $contents += [Environment]::NewLine
        }
        $contents += "ORBIT_APP_KEY_FILE=$AppKeyPath" + [Environment]::NewLine
        [System.IO.File]::WriteAllText(
            $ConfigPath,
            $contents,
            (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Added ORBIT_APP_KEY_FILE=$AppKeyPath to $ConfigPath"
    }
}

Set-FileAclReadOnly $ConfigPath

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
if ($AppKeyPath -and (Test-Path -LiteralPath $AppKeyPath)) {
    Write-Host "  key:    $AppKeyPath"
}
Write-Host "  status: sc.exe query $ServiceName"
