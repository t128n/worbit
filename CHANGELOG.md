# Changelog

## 0.3.0+3

- Create the app key during install when `ORBIT_APP_KEY_FILE` is missing, using
  APIs available in the built-in Windows PowerShell 5.1. The key file is
  restricted to SYSTEM, Administrators, and the service account.
- Add `ORBIT_APP_KEY_FILE` to the env file when neither that setting nor
  `ORBIT_APP_KEY` is present.
- Document trying Orbit in development mode before installing the service,
  including console/log behaviour and the loopback restriction.
- Run the native service install test under Windows PowerShell 5.1.

## 0.3.0+2

- Add configurable GitHub Enterprise hosts (`ORBIT_GITHUB_URL`) for GHES and
  GHEC with data residency.
- Derive REST, GraphQL, OAuth, App manifest, installation, issue and pull URLs
  from the configured host.
- Thread the host through sign-in, 2FA, integrations, link previews, CSP and
  task links.
- Bind the database to the first GitHub host. The binding lives in an unmanaged
  `worbit_github_host_binding` table, so the main Orbit schema version stays
  stock `0092`.
- Drop polling entirely. GHE deployments use inbound webhooks.

## 0.3.0+1

Initial scaffold.

- Standalone build repo pinned to Orbit `v0.3.0`.
- Native Windows Service patch (`0001`): SCM install/uninstall, service-name and
  env-file arguments, `ORBIT_LOG_FILE`, Windows backup rename fixes.
- PowerShell bootstrap/verify/apply/build/package scripts.
- Windows install/uninstall helpers with ACLs and a recorded env file.
- CI: Windows build, binary smoke test, native service install/start/stop test,
  patch verification against upstream tags, release packaging.
