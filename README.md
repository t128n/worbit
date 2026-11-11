# worbit

Reproducible Windows builds of [Orbit](https://github.com/coollabsio/orbit) with:

- a **native Windows Service** (`orbit service install`), no WinSW or NSSM;
- **GitHub Enterprise** host support (GHES and GHEC with data residency);
- **polling sync** for installations that cannot receive inbound webhooks.

`worbit` is not a fork. It pins one upstream release tag, applies a small patch
series, and publishes a Windows binary plus install scripts. Upstream source is
never vendored in this repository.

## Status

| Piece | State |
|---|---|
| `0001` native Windows Service | implemented in `patches/` |
| `0002` GitHub Enterprise host | port pending from `t128n/orbit-cx` |
| `0003` GitHub polling sync | port pending from `t128n/orbit-cx` |
| Windows CI + service smoke test | scaffolded |
| Release packaging | scaffolded |

Until `0002` and `0003` land, the build is stock Orbit plus the Windows
Service patch.

## How it works

```text
coollabsio/orbit @ upstream.lock
        +
patches/series (in order)
        =
artifacts/worbit-windows-x86_64-<version>.zip
```

- `upstream.lock` pins the exact upstream tag and commit.
- `patches/series` is the ordered patch list.
- `scripts/bootstrap.ps1` checks out the pinned commit into `.work/orbit`.
- `scripts/verify.ps1` proves the whole series applies before anything is built.
- `.work/` is disposable and gitignored.

## Build

Requirements:

- Windows 10/11 or Windows Server 2022/2025
- Visual Studio Build Tools with **Desktop development with C++**
- Rust `1.97.1` (the upstream `rust-toolchain.toml` pins it)
- Bun `1.4.4`
- Git for Windows
- PowerShell 7

```powershell
git clone https://github.com/t128n/worbit
cd worbit
./scripts/bootstrap.ps1
./scripts/verify.ps1
./scripts/apply.ps1
./scripts/build.ps1
./scripts/package.ps1
```

The binary is `.work/orbit/target/release/orbit.exe`; the zip is under
`artifacts/`.

## Install as a Windows Service

The published zip contains `orbit.exe`, `install.ps1`, `uninstall.ps1`, and
`worbit.env.example`.

```powershell
# 1. Copy the zip contents somewhere temporary.
# 2. Edit worbit.env for your server.
# 3. Run from an elevated prompt:
./install.ps1 -EnvFile .\worbit.env
```

`install.ps1` copies `orbit.exe` to a stable path, applies directory ACLs,
validates the configuration, and registers the service with the SCM.

```powershell
Start-Service Orbit
sc.exe query Orbit
Stop-Service Orbit
./uninstall.ps1
```

See [docs/deploy-windows.md](docs/deploy-windows.md) for the reverse proxy,
ACLs, upgrade, and rollback procedure.

## Releases

Tags are `worbit-v<upstream>+<overlay>`, for example `worbit-v0.3.0+1`.
`VERSION` must match the tag without the `worbit-v` prefix.

Each release contains:

- `worbit-windows-x86_64-<version>.zip`
- `SHA256SUMS`

## Layout

```text
patches/        ordered upstream patches
scripts/        bootstrap, verify, apply, build, package
windows/        native-service install/uninstall helpers and env example
docs/           build, deployment, GitHub, polling, patch, upgrade notes
tests/          binary and service smoke tests
.github/        build, patch-verification, and release workflows
```

## Upstream contributions

The generic pieces belong upstream. `worbit` keeps the fork
[`t128n/orbit-cx`](https://github.com/t128n/orbit-cx) as the authoring and PR
vehicle; this repository only pins and builds.

## License

`worbit` patches and scripts are Apache-2.0. Built binaries contain Orbit and
remain subject to Orbit's Apache-2.0 license and notices. See [LICENSE](LICENSE)
and [NOTICE](NOTICE).
