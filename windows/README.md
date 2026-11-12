# Windows service scripts

The published zip contains these scripts next to `orbit.exe`.

## Try it before installing

`orbit.exe` runs from the extracted folder without registering the service. Use
a development configuration and paths under the extraction directory:

```dotenv
# test.env
ORBIT_ENV=development
ORBIT_BIND=127.0.0.1
ORBIT_PORT=8080
ORBIT_DATABASE_PATH=C:\Temp\worbit\data\orbit.sqlite
ORBIT_ATTACHMENTS_PATH=C:\Temp\worbit\data\attachments
ORBIT_BACKUPS_PATH=C:\Temp\worbit\backups
ORBIT_APP_KEY_FILE=C:\Temp\worbit\app.key
```

Do not set `ORBIT_TRUSTED_PROXIES` in development, and leave out
`ORBIT_LOG_FILE`: with a log file configured, runtime logs go there instead of
the console. Create the key once with Windows PowerShell 5.1 or later:

```powershell
$bytes = [byte[]]::new(32)
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
[System.IO.File]::WriteAllText(
  "C:\Temp\worbit\app.key",
  [Convert]::ToBase64String($bytes),
  [System.Text.Encoding]::ASCII)
```

Then start it:

```powershell
$env:ORBIT_ENV_FILE = "C:\Temp\worbit\test.env"
.\orbit.exe config check
.\orbit.exe serve
```

`serve` does not print a "listening" line. While setup is incomplete it prints
`Initial setup URL: ...`; otherwise the console stays quiet. Confirm the
listener and open `http://127.0.0.1:8080` on the server itself; `127.0.0.1` in
another machine's browser points at that machine, and development mode refuses a
non-loopback bind.

```powershell
Get-NetTCPConnection -State Listen -LocalPort 8080
Invoke-WebRequest http://127.0.0.1:8080/health/live -UseBasicParsing
```

See `docs/deploy-windows.md` in the zip for the full test and troubleshooting
steps.

## Install

1. Extract the zip to a temporary directory.
2. Copy `worbit.env.example` to `worbit.env` and edit it.
3. From an elevated prompt:

```powershell
./install.ps1 -EnvFile .\worbit.env
```

`install.ps1`:

- copies `orbit.exe` to `C:\Program Files\Worbit\orbit.exe`;
- creates `C:\ProgramData\Worbit\{data,backups,logs,config}`;
- restricts the data and config directories to SYSTEM and Administrators;
- copies the env file to `C:\ProgramData\Worbit\config\worbit.env`;
- creates the app key at `ORBIT_APP_KEY_FILE` if that file is missing (unless
  `ORBIT_APP_KEY` is set), adding the setting to the env file when it is absent;
- runs `orbit.exe config check`;
- registers the service with `orbit.exe service install --name Orbit --env-file ...`;
- starts it and waits for the Running state.

Back up the generated key immediately: it is not in the database backup, and a
restored database cannot decrypt saved secrets without it.

The env-file path is recorded in the service's launch arguments, so the service
reads the same configuration after a reboot without machine-wide variables.

## Manage

```powershell
Start-Service Orbit
Stop-Service Orbit
sc.exe query Orbit
Get-Content C:\ProgramData\Worbit\logs\orbit.log -Tail 100 -Wait
```

`Stop-Service` sends the SCM stop control; Orbit cancels its shutdown token and
drains HTTP the same way it does on SIGTERM.

## Upgrade

```powershell
Stop-Service Orbit
./install.ps1 -EnvFile .\worbit.env
```

Keep the previous `orbit.exe` and a verified backup until the new version has
started and migrated successfully.

## Uninstall

```powershell
./uninstall.ps1                 # removes the service, keeps data
./uninstall.ps1 -RemoveFiles    # also deletes install and data directories
```

## Service account

The default account is LocalSystem. To use a dedicated account:

```powershell
$cred = Get-Credential
./install.ps1 -EnvFile .\worbit.env -Account $cred.UserName -Password $cred.GetNetworkCredential().Password
```

The account needs "Log on as a service" and full control of
`C:\ProgramData\Worbit`. The install script grants the directory ACL; grant the
logon right with `secpol.msc` or `ntrights`.
