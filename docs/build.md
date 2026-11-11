# Build worbit

## Prerequisites

- Windows 10/11 or Windows Server 2022/2025, x64
- Visual Studio Build Tools 2022 with **Desktop development with C++**
- Rust `1.97.1` (`rustup toolchain install 1.97.1`)
- Bun `1.4.4`
- Git for Windows
- PowerShell 7 (`pwsh`)

The upstream workspace pins Rust in `rust-toolchain.toml`; `rustup` selects it
automatically inside `.work/orbit`.

## Build from the pinned tag

```powershell
git clone https://github.com/t128n/worbit
cd worbit

./scripts/bootstrap.ps1   # clone upstream at upstream.lock
./scripts/verify.ps1      # cumulative git apply --check
./scripts/apply.ps1       # patch the checkout
./scripts/build.ps1       # bun build + cargo build --release
./scripts/package.ps1     # artifacts/worbit-windows-x86_64-<version>.zip
```

Outputs:

- `.work/orbit/target/release/orbit.exe`
- `artifacts/worbit-windows-x86_64-<version>.zip`
- `artifacts/SHA256SUMS`

## What the build does

1. `bun install --frozen-lockfile --filter web`
2. `bun run build` in `apps/web`
3. `cargo build --locked --release -p orbit-server`

The Rust binary embeds `apps/web/dist` with `include_dir!`, so the web build must
run first. A bare `cargo check` in a fresh checkout fails with
`include_dir!` reporting that `apps/web/dist` is not a directory. That is
expected; run the web build or create a temporary placeholder only for
type-checking.

`ORBIT_BUILD_REVISION` is set to the upstream commit short SHA so the binary
reports which source it came from.

## Refresh to a newer upstream release

1. Change `tag` and `commit` in `upstream.lock`.
2. Run `./scripts/bootstrap.ps1`.
3. Run `./scripts/verify.ps1`.
4. Rebase the patch series until it passes, then build.

See [patches.md](patches.md).

## Troubleshooting

**`link.exe` not found** — install the C++ build tools and run the build from a
Developer PowerShell, or reopen the shell after installing.

**`bun install` fails on the lockfile** — confirm Bun `1.4.4`; the upstream
lockfile is version-sensitive.

**Patch check passes but the build fails** — the series applied, but upstream
changed an API. Build locally, fix the checkout, then export the corrected
patch from the authoring fork. Do not hand-edit patch files.
