# Patch inventory

Base: **Orbit v0.3.0**, commit `a7402204c7cadcac4747cbf47a60685a20f59498`.

| Patch | Upstream | Contents |
|---|---|---|
| `0001-feat-windows-native-service.patch` | #81 | Native SCM service, `--name`/`--env-file`, `ORBIT_LOG_FILE`, Windows backup rename fixes |
| `0002-feat-github-enterprise-host.patch` | #82 | Configurable GHES/GHEC host, derived endpoints, host binding |

Polling is not included.

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

## 0002 details

Code:

- `crates/platform/src/github.rs` — `GitHubHost`, host validation and derived
  endpoints.
- `crates/platform/src/config.rs` — `ORBIT_GITHUB_URL`.
- `apps/server/src/sign_in_providers.rs`, `auth_routes/`, `repositories/` —
  GitHub OAuth and 2FA use the configured host.
- `apps/server/src/integration_routes.rs` — App manifest, installation and
  webhook URLs use the configured host.
- `apps/server/src/task_routes.rs`, `repositories/tasks.rs` — issue/pull URLs
  use the configured host.
- `crates/platform/src/http/security.rs` — CSP `form-action` includes the host.
- `apps/server/src/github_binding.rs` — refuses to change hosts after GitHub
  data exists.

The binding table is created by code, not by a migration:

```sql
CREATE TABLE IF NOT EXISTS worbit_github_host_binding (
    singleton BIGINT PRIMARY KEY CHECK (singleton = 1),
    origin TEXT NOT NULL
);
```

That keeps `schema_migrations` at the stock Orbit version. The `worbit_` prefix
avoids a collision if upstream ever adds its own binding table.

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

Do not add a custom migration for worbit-only schema. Create an unmanaged
`worbit_*` table at startup instead. Upstream is already past `0099` on `main`;
a custom migration makes the database unreadable by stock Orbit.
