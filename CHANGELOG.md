# Changelog

## 0.3.0+1

Initial scaffold.

- Standalone build repo pinned to Orbit `v0.3.0`.
- Native Windows Service patch (`0001`): SCM install/uninstall, service-name and
  env-file arguments, `ORBIT_LOG_FILE`, Windows backup rename fixes.
- PowerShell bootstrap/verify/apply/build/package scripts.
- Windows install/uninstall helpers with ACLs and a recorded env file.
- CI: Windows build, binary smoke test, native service install/start/stop test,
  patch verification against upstream tags, release packaging.

GHEC host support (`0002`) and GitHub polling sync (`0003`) are pending ports
from `t128n/orbit`.
