# Windows service scripts

The published zip contains these scripts next to `orbit.exe`.

## Install

1. Extract the zip to a temporary directory.
2. Copy `worbit.env.example` to `worbit.env` and edit it.
3. Generate the app key and save it as `app.key` (one base64 line).
4. From an elevated prompt:

```powershell
./install.ps1 -EnvFile .\worbit.env
```

`install.ps1`:

- copies `orbit.exe` to `C:\Program Files\Worbit\orbit.exe`;
- creates `C:\ProgramData\Worbit\{data,backups,logs,config}`;
- restricts the data and config directories to SYSTEM and Administrators;
- copies the env file to `C:\ProgramData\Worbit\config\worbit.env`;
- runs `orbit.exe config check`;
- registers the service with `orbit.exe service install --name Orbit --env-file ...`;
- starts it and waits for the Running state.

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
