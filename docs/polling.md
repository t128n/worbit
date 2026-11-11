# GitHub polling sync

> Status: the polling patch (`0003`) is being ported from `t128n/orbit-cx`.
> Until it lands, the build uses webhooks only.

## Why polling

Orbit normally receives GitHub App webhooks at
`{ORBIT_PUBLIC_ORIGIN}/api/v1/integrations/github/webhook`. When GitHub cannot
route to the Orbit server — GHEC in another network, a firewall, or a reverse
proxy without an inbound path — Orbit can instead ask GitHub for changes on a
schedule.

## Modes

A per-workspace sync setting has two values:

- **Webhooks** — default, current behaviour.
- **Polling** — no inbound route required.

## Polling behaviour

- Lists issues and pull requests carrying the project's label in the connected
  repository.
- Applies the same rules as webhooks: create, update, complete on merge, cancel
  on close, resume on reopen, pause when the label is removed.
- Detects removed labels by comparing the full labeled set with the links Orbit
  already has; an incremental `since` query alone cannot see removals.
- Runs on a configurable interval (1–15 minutes, default 5).
- Backs off with jitter when GitHub returns 403/429, honouring `Retry-After`
  and `X-RateLimit-Reset`.
- Serializes runs per workspace and repository so overlapping polls cannot
  duplicate transitions.
- Offers **Sync now** for an immediate run.

## Operational checks

- The installation token is short-lived and cached; it is never logged.
- The App private key stays encrypted with `ORBIT_APP_KEY`.
- Polling survives a service restart: the cursor and schedule are durable.
- A full enumeration is cheap enough for the repository size; check the rate
  limit budget before lowering the interval below 5 minutes.
- GitHub is untrusted input: treat titles, bodies, labels, and user names as
  data, not markup.

## Configuration

The setting is stored per workspace in the GitHub integration, not in
`worbit.env`. A future environment override may expose the interval; keep the
UI as the source of truth.
