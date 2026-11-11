# Upgrade and rollback

## Before upgrading

1. Read the upstream release notes for the tag in `upstream.lock`.
2. Create and verify a backup:

```powershell
Stop-Service Orbit
& "C:\Program Files\Worbit\orbit.exe" backup create
& "C:\Program Files\Worbit\orbit.exe" backup verify <id>
```

3. Copy the current `C:\Program Files\Worbit\orbit.exe` to a rollback path.
4. Keep `C:\ProgramData\Worbit\config\worbit.env` and the app key.

Use the service account's environment file when running CLI commands:

```powershell
$env:ORBIT_ENV_FILE = "C:\ProgramData\Worbit\config\worbit.env"
```

## Replace the binary

The service registration already points at `C:\Program Files\Worbit\orbit.exe`;
replacing that file keeps the launch arguments and env-file path.

```powershell
Stop-Service Orbit
Copy-Item .\orbit.exe "C:\Program Files\Worbit\orbit.exe" -Force
Start-Service Orbit
```

Migrations run at startup. If the process exits, read
`C:\ProgramData\Worbit\logs\orbit.log` before retrying.

If the install path or service name changes, rerun `install.ps1` instead:

```powershell
./install.ps1 -EnvFile C:\ProgramData\Worbit\config\worbit.env
```

## Verify

```powershell
Get-Service Orbit
Invoke-WebRequest http://127.0.0.1:8080/health/ready
Get-Content C:\ProgramData\Worbit\logs\orbit.log -Tail 100
```

Then check the UI, an existing task, and a GitHub link.

## Rollback

1. Stop the service.
2. Restore the pre-upgrade backup with the matching binary:

```powershell
& "C:\Program Files\Worbit\orbit.exe" backup restore <id>
```

3. Put the saved `orbit.exe` back.
4. Start the service.

An older binary cannot read a database migrated by a newer one. Restore the
backup taken before the upgrade, not just the old executable. Data written after
the upgrade is lost unless it is exported separately.

## App key

A restored database needs the same `ORBIT_APP_KEY`. Without it, saved secrets
(SMTP password, GitHub App keys, import tokens) cannot be decrypted. Keep the
key outside the database backup.
