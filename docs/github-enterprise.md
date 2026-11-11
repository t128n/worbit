# GitHub Enterprise

> Status: the configurable-host patch (`0002`) is being ported from
> `t128n/orbit`. Until it lands, the build talks only to `github.com`.

## GHES versus GHEC

The host setting must distinguish two layouts:

| Deployment | Web host | REST API base |
|---|---|---|
| GitHub.com | `https://github.com` | `https://api.github.com` |
| GHES | `https://ghe.example.com` | `https://ghe.example.com/api/v3` |
| GHEC with data residency | `https://acme.ghe.com` | `https://api.acme.ghe.com` |

A single `ORBIT_GITHUB_URL` covers the web host; derive the API base per
deployment instead of appending `/api/v3` unconditionally. GHEC data-residency
hosts do **not** use `/api/v3`.

## What the patch changes

- App manifest registration URL
- Manifest code conversion endpoint
- App installation URL
- GitHub sign-in OAuth authorize/token endpoints
- GitHub REST calls
- Link-preview allowlist and the CSP `form-action` origin
- Validation of `ORBIT_GITHUB_URL` (HTTPS, no credentials, no query/fragment)

## Configuration

```dotenv
ORBIT_GITHUB_URL=https://acme.ghe.com
```

Default remains `https://github.com`.

Private GHES hosts are legitimate. Allow them explicitly; do not treat every
private address as an SSRF failure, but keep the setting admin-only and validate
the scheme.

## Create the GitHub App

1. Open `https://<host>/settings/apps/new` (organization settings for an org
   owner).
2. Use the manifest flow Orbit presents.
3. Grant the same repository permissions Orbit uses on github.com.
4. Install the App on the repositories Orbit should sync.

For polling, the App needs the same permissions; no inbound webhook route is
required.

## Webhooks versus polling

- **Webhooks**: GitHub must be able to reach `{origin}/api/v1/integrations/github/webhook`.
- **Polling**: Orbit reaches GitHub on a schedule. Use it when GitHub cannot
  route to the Orbit server, including GHEC behind a private network.

See [polling.md](polling.md).

## Verification

- The manifest conversion succeeds and stores an App ID, slug, and private key.
- The installation list returns the expected account and repositories.
- A test issue with the project label appears as an Orbit task.
- Removing the label pauses the link; re-adding it resumes.
- Sign-in with GitHub returns to the configured host, not github.com.
