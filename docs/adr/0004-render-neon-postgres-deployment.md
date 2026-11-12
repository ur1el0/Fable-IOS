# ADR 0004: Render and Neon deployment

- **Status:** Accepted
- **Date:** 2026-11-12

## Context

The backend currently uses SQLite for zero-setup development and local runs. Render's Free web service has an ephemeral filesystem, so a SQLite file on the service would lose application data during restarts, redeploys, and idle spin-down. The user requested a $0 Render and Neon deployment.

## Decision

Keep SQLite as the default backend for local development and tests. Add a PostgreSQL connection path selected by `FABLE_DATABASE_BACKEND=postgres` and `DATABASE_URL`, then use Neon as the persistent hosted database. Deploy the existing Docker backend as a Render Free web service with an HTTP health check and the Render-assigned port. Use a pooled Neon TLS connection string.

## Consequences

- The application schema is initialized in Neon on service startup, with a dedicated schema-version table and an advisory lock to serialize startup migrations.
- PostgreSQL-specific transaction locks preserve per-key rate-limit and shelf reconciliation behavior across concurrent API calls.
- Local SQLite files and hosted Neon data remain separate; migration is an explicit operator task.
- Render Free services sleep when idle and have no persistent disk. Neon Free has monthly compute and storage limits; these services are suitable for development or low-volume demonstration, not guaranteed production availability.
- Render Free blocks outbound SMTP ports 25, 465, and 587, so password-reset delivery through the current Gmail SMTP integration requires a different mail transport or hosting plan.
