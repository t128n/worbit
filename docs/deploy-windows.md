# Deploy worbit on Windows Server

## Shape of the deployment

```text
client ── HTTPS ──> IIS/ARR or Caddy ── HTTP ──> orbit.exe (Windows Service)
                                                   ├─ SQLite (local disk)
                                                   ├─ attachments (local disk)
                                                   └─ backups (local disk)
```

Orbit binds to `127.0.0.1`; the reverse proxy terminates TLS. The service runs
under the SCM and starts automatically at boot.

## Prerequisites

- Windows Server 2022/2025
- A DNS name and a certificate for the public origin
- A reverse proxy (IIS with ARR, Caddy, or equivalent)
- Local disk for the database, attachments, and backups. Do not use SMB shares
  for the SQLite database or its WAL files.

## Install

```powershell
# Elevated prompt
Expand-Archive .\worbit-windows-x86_64-0.3.0+1.zip C:\Temp\worbit
cd C:\Temp\worbit

Copy-Item .\worbit.env.example .\worbit.env
notepad .\worbit.env

# Generate the app key once and save it as a single line.
$key = [byte[]]::new(32)
[Security.Cryptography.RandomNumberGenerator]::Fill($key)
[Convert]::ToBase64String($key) |
  Set-Content C:\ProgramData\Worbit\config\app.key -NoNewline

.\install.ps1 -EnvFile .\worbit.env
```

`install.ps1` installs to `C:\Program Files\Worbit`, keeps state under
`C:\ProgramData\Worbit`, applies ACLs, validates the configuration, registers
the service, and starts it.

## Configuration

`C:\ProgramData\Worbit\config\worbit.env` is read at every service start.

```dotenv
ORBIT_ENV=production
ORBIT_BIND=127.0.0.1
ORBIT_PORT=8080
ORBIT_PUBLIC_ORIGIN=https://orbit.example.com
ORBIT_TRUSTED_PROXIES=127.0.0.1/32
ORBIT_DATABASE_PATH=C:\ProgramData\Worbit\data\orbit.sqlite
ORBIT_ATTACHMENTS_PATH=C:\ProgramData\Worbit\data\attachments
ORBIT_BACKUPS_PATH=C:\ProgramData\Worbit\backups
ORBIT_APP_KEY_FILE=C:\ProgramData\Worbit\config\app.key
ORBIT_LOG_FILE=C:\ProgramData\Worbit\logs\orbit.log
```

Production validation refuses to start without an HTTPS `ORBIT_PUBLIC_ORIGIN`
and at least one trusted proxy network. Add the proxy addresses; never use
`0.0.0.0/0` or `::/0`.

## Reverse proxy

Caddy:

```caddyfile
orbit.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

IIS with ARR:

1. Create an HTTPS site with the certificate.
2. Enable ARR and URL Rewrite.
3. Proxy `https://orbit.example.com/*` to `http://127.0.0.1:8080/*`.
4. Preserve `Host` and set `X-Forwarded-Proto: https`.
5. Allow large uploads in `Request Filtering` (Orbit defaults to 100 MiB per
   request).

Firewall the Orbit port so only the proxy host can reach it. Do not expose
`127.0.0.1:8080` directly.

## Service account

The default is LocalSystem. A dedicated account is better:

```powershell
$cred = Get-Credential
.\install.ps1 -EnvFile .\worbit.env -Account $cred.UserName `
  -Password $cred.GetNetworkCredential().Password
```

Grant "Log on as a service" and full control of `C:\ProgramData\Worbit`.
`install.ps1` applies the directory ACL; `secpol.msc` grants the logon right.

## Logs

The native service has no console. `ORBIT_LOG_FILE` is required; the install
script points it at `C:\ProgramData\Worbit\logs\orbit.log`.

The file is append-only. Rotate it with a scheduled task, or use an external log
collector. Example scheduled task action:

```powershell
$log = "C:\ProgramData\Worbit\logs\orbit.log"
if (Test-Path $log) {
    Move-Item $log "$log.$(Get-Date -Format yyyyMMdd-HHmmss)"
}
```

Orbit reopens the file only at process start. Restart the service after moving
it, or copy/truncate with a collector that supports reopen notifications.

## Health and readiness

- `GET /health/live` — process liveness
- `GET /health/ready` — dependencies and shutdown state

Use `/health/ready` for the load balancer. The built-in CLI check is:

```powershell
orbit.exe healthcheck
```

Run it with `ORBIT_ENV_FILE` set, or from the service account context.

## Backup

```powershell
Stop-Service Orbit
orbit.exe backup create
orbit.exe backup verify <id>
Start-Service Orbit
```

`ORBIT_BACKUPS_PATH` must be outside the attachment directory. Keep a copy off
the server. The app key is not in the database backup; store it separately.

## Upgrade and rollback

See [upgrade.md](upgrade.md).
