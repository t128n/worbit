# GitHub Enterprise

`worbit` adds one setting, `ORBIT_GITHUB_URL`, and uses it for every GitHub
URL and API call. It supports GitHub Enterprise Server and GitHub Enterprise
Cloud with data residency.

## GHES versus GHEC

| Deployment | `ORBIT_GITHUB_URL` | REST API base |
|---|---|---|
| GitHub.com | unset or `https://github.com` | `https://api.github.com/` |
| GHES | `https://ghe.example.com` | `https://ghe.example.com/api/v3/` |
| GHEC with data residency | `https://acme.ghe.com` | `https://api.acme.ghe.com/` |

The host parser rejects HTTP, credentials, paths, query strings, fragments and
multi-label `*.ghe.com` hosts. GHEC data-residency hosts do not use `/api/v3`.

## What changes

- GitHub sign-in OAuth authorize and token URLs
- GitHub App manifest URL and manifest-code conversion endpoint
- App installation URL
- GitHub REST and GraphQL calls
- Issue and pull-request links stored on tasks
- Link-preview allowlist and the CSP `form-action` origin

## Configuration

```dotenv
ORBIT_GITHUB_URL=https://acme.ghe.com
```

Leave it unset for github.com. Set it before the first GitHub App, sign-in
provider or task link is created.

## Host binding

The first startup with GitHub data binds the database to one origin:

- Existing legacy GitHub data binds to `https://github.com`.
- A new database binds to the configured host.
- A later startup with a different host is refused with a clear error.

The binding lives in an unmanaged table, created by code:

```sql
CREATE TABLE IF NOT EXISTS worbit_github_host_binding (
    singleton BIGINT PRIMARY KEY CHECK (singleton = 1),
    origin TEXT NOT NULL
);
```

It is deliberately not a migration. The main `schema_migrations` stays at the
stock Orbit version, so an official Orbit binary can still open the database.
The `worbit_` prefix avoids a collision if upstream adds the same feature.

Treat the host as immutable for the life of the database. Changing it would
point existing App IDs, installation IDs and identity subjects at a different
GitHub instance.

## Create the GitHub App

1. Open `https://<host>/settings/apps/new` as an organization owner.
2. Use the manifest flow Orbit presents.
3. Grant the repository permissions Orbit uses on github.com.
4. Install the App on the repositories Orbit should sync.
5. Configure the webhook URL to
   `https://<orbit-origin>/api/v1/integrations/github/webhook`.

The GitHub instance must be able to reach that URL. Polling is not part of
`worbit`; a network where GitHub cannot reach Orbit needs a reverse proxy,
tunnel, or a different deployment.

## Verification

- The manifest conversion succeeds and stores an App ID, slug, and private key.
- The installation list returns the expected account and repositories.
- A test issue with the project label appears as an Orbit task.
- Removing the label pauses the link; adding it back resumes.
- Sign-in with GitHub returns to the configured host, not github.com.
- An issue link points at `https://<host>/<owner>/<repo>/issues/<n>`.
