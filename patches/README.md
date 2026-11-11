# Patch inventory

Base: **Orbit v0.3.0**, commit `a7402204c7cadcac4747cbf47a60685a20f59498`.

| Patch | Upstream | Contents |
|---|---|---|
| `0001-feat-windows-native-service.patch` | #81 | Native SCM service, `--name`/`--env-file`, `ORBIT_LOG_FILE`, Windows backup rename fixes |
| `0002-feat-ghec-host.patch` | #82 | Pending port from `t128n/orbit-cx` |
| `0003-feat-github-polling.patch` | #83 | Pending port from `t128n/orbit-cx` |

## 0001 details

Code:

- `apps/server/src/windows_service.rs` — SCM dispatcher, `service install` /
  `uninstall`, control handler wired to the existing shutdown token.
- `apps/server/src/cli.rs` — `orbit service install|uninstall --name`,
  `--env-file`.
- `apps/server/src/main.rs` — early dispatch and env-file loading.
- `crates/platform/src/observability.rs` — `ORBIT_LOG_FILE` (append, falls back
  to stdout).
- `crates/platform/src/config.rs` — `ORBIT_LOG_FILE` and `ORBIT_ENV_FILE`.
- `crates/platform/src/backup.rs` — Windows restore fixes: `FILE_SHARE_DELETE`
  on the staged database handle, retry on `ERROR_SHARING_VIOLATION` from
  antivirus scanning.
- `apps/server/Cargo.toml`, `Cargo.lock` — `windows-service 0.8.1`, target-gated.

The env file is recorded in the service launch arguments, so a reboot does not
depend on machine-wide `ORBIT_*` variables:

```text
orbit.exe __service-run --name Orbit --env-file C:\ProgramData\Worbit\config\worbit.env
```

## Generating a patch

Use `git format-patch` from the authoring fork; do not edit the `.patch` file.

```bash
git format-patch v0.3.0..release/cx-v0.3.0 \
  --output-directory ../worbit/patches
```

Keep the subject, author, date, and body. Rename to
`NNNN-type-slug.patch` and add the name to `series`.

## Rebase notes

`verify.ps1` checks the whole series cumulatively. When a patch fails:

1. Reproduce on the authoring branch with `git am -3`.
2. Resolve conflicts with `git rerere` enabled.
3. Build and run the Windows tests.
4. Re-export the patch and rerun `verify.ps1`.

Migration numbers are the most common collision. Upstream is already past
`0099` on `main`; use the next free number in both migration directories.
