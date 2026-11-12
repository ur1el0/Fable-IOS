# Backend Operations

## Deployment boundary

The backend listens on container port 8000. Docker Compose publishes it on host port 8001 by default (`FABLE_PORT`), bound to `127.0.0.1`. In production, place it behind a TLS-terminating reverse proxy or managed ingress and keep the container port private to that proxy. Set `FABLE_BIND_ADDRESS=0.0.0.0` only for a trusted development LAN.

Uvicorn's proxy middleware only accepts forwarded headers from peers listed in `FORWARDED_ALLOW_IPS`. Set that variable to the reverse-proxy source IP addresses or networks for the deployment; do not use `*`. The proxy must replace incoming `X-Forwarded-For` values with the observed client address. Fable's application middleware ignores raw forwarded headers and uses the ASGI client address, so an untrusted header cannot change a rate-limit bucket. If the proxy address is not trusted, clients will share the proxy's rate-limit bucket.

Set `FABLE_ENV=production` and provide the allowed browser origins in `FABLE_CORS_ORIGINS` as a JSON array (`CORS_ORIGINS` is accepted as a compatibility alias). `FABLE_ENV` is required and must be one of `development`, `dev`, `local`, `test`, `staging`, `production`, or `prod`; a missing or misspelled value stops application startup. Native iOS requests do not require a browser origin. Production startup rejects wildcard CORS origins.

Authentication endpoints use SQLite-backed per-IP and per-account/IP limits. Defaults are 5 registrations and 60 login attempts per IP per 15 minutes, plus 10 login attempts per account/IP per window. Password recovery defaults to 10 requests per IP and 5 per account/IP per window. Tune `FABLE_AUTH_RATE_WINDOW_SECONDS`, `FABLE_AUTH_REGISTER_LIMIT_PER_IP`, `FABLE_AUTH_LOGIN_LIMIT_PER_IP`, `FABLE_AUTH_LOGIN_LIMIT_PER_ACCOUNT_IP`, `FABLE_AUTH_PASSWORD_RESET_LIMIT_PER_IP`, and `FABLE_AUTH_PASSWORD_RESET_LIMIT_PER_ACCOUNT_IP` for the deployment. The limits use the ASGI client address; configure a trusted proxy so that address reflects the client IP without accepting untrusted forwarded headers. Request bodies default to 256 KiB and can be adjusted with `FABLE_MAX_REQUEST_BODY_BYTES`.

The API token-bucket limiter is enabled by default. `FABLE_RATE_LIMIT_ENABLED` accepts `true`/`false`, `1`/`0`, `yes`/`no`, or `on`/`off` (case-insensitive); any other value stops application startup instead of silently disabling limits. The limiter stores at most `FABLE_RATE_LIMIT_MAX_CLIENT_BUCKETS` client/tier buckets (default 10,000) in SQLite. Workers sharing the same `FABLE_DB_PATH` share the same counters; stale buckets are pruned, and new client keys are temporarily rejected if the bucket table reaches capacity. Each request updates one bucket in a short SQLite transaction. Authentication and provider ingestion use the stricter auth tier; tune `RATE_LIMIT_AUTH_LIMIT` and `RATE_LIMIT_AUTH_WINDOW` if needed. Authentication-specific registration, login, and password-reset windows are also stored in SQLite. Separate hosts with separate database files do not share counters, so enforce limits at the trusted edge before horizontally scaling beyond one shared SQLite host.

The Compose API container runs as the configured non-root UID/GID with a read-only root filesystem, a small `noexec`/`nosuid` `/tmp`, all Linux capabilities dropped, `no-new-privileges`, and a 128-process limit. Its `/app/data` mount remains writable for SQLite. Keep any additional writable paths explicit as dedicated mounts instead of disabling the read-only root filesystem.

Password recovery requires SMTP configuration through `FABLE_SMTP_HOST`, `FABLE_SMTP_PORT`, and `FABLE_SMTP_FROM_EMAIL`. SMTP authentication credentials are optional as a pair. Port 465 uses implicit TLS; other ports must support STARTTLS. Recovery requests return the same accepted response for existing and unknown addresses, email a one-time code that expires after 15 minutes, and revoke all active sessions after a successful reset. Users enter the code in the in-app recovery form. Delivery runs in a background task; configure and monitor SMTP before advertising recovery as available.

## Provider ingestion and resource limits

The provider ingestion routes write live Gutenberg and MangaDex content into SQLite and require the operator-only `X-Fable-Ingestion-Key` header. Set `FABLE_INGESTION_API_KEY` from a secret manager to a random value with at least 32 bytes of entropy. For example, generate 32 random bytes as hexadecimal with `python3 -c 'import secrets; print(secrets.token_hex(32))'`. If the key is missing or shorter than 32 bytes, ingestion fails closed with HTTP 503; a missing or incorrect request key returns HTTP 401. Never place this key in the iOS app or a public client.

Provider work has fixed process limits: Gutenberg text downloads are streamed and capped at 8 MiB, chapter fetches run at most three concurrently, and its chapter cache holds at most 32 entries / 16 MiB for 10 minutes. Manga provider responses are streamed and capped at 2 MiB, upstream calls run at most five concurrently, and its LRU cache holds at most 128 entries / 16 MiB for 10 minutes. These limits are intentionally enforced in the service layer rather than exposed as per-request controls.

For iOS Release builds, set the Xcode build setting `FABLE_API_BASE_URL` to the deployed HTTPS API root, for example `https://api.example.com/api/v1`, replacing the example host with the deployed host. Release builds fail when the value is missing, is not HTTPS, or uses a loopback, unspecified, or reserved local host. Debug builds retain the simulator URL.

## SQLite backup

Create and store a 256-bit backup key in the deployment secret manager. Generate a key with:

```bash
python3 -c 'import base64, secrets; print(base64.b64encode(secrets.token_bytes(32)).decode())'
```

Set the secret as `FABLE_BACKUP_ENCRYPTION_KEY_B64` for backup commands and the Compose backup service. Keep it separate from the backup destination; a backup cannot be restored without the matching key. Do not rotate the key until every backup encrypted with it has expired, or retain the old key in the secret manager for the full backup-retention period.

Create and verify an encrypted, transactionally consistent snapshot with Python's SQLite backup API and authenticated encryption:

```bash
python3 scripts/sqlite_backup.py backup data/fable.sqlite3 backups/fable-YYYY-MM-DD.sqlite3.enc
python3 scripts/sqlite_backup.py verify backups/fable-YYYY-MM-DD.sqlite3.enc
```

Use the actual path configured by `FABLE_DB_PATH` if it differs. Store backups outside the application data directory, restrict access, and mount durable off-host storage at the configured path for disaster recovery. The encrypted artifact can be copied off-host without exposing SQLite contents; encrypted storage at the destination remains recommended as a separate layer.

To migrate a pre-existing plaintext snapshot, encrypt it in place to a new filename, verify the encrypted copy, and complete a restore drill before deleting the plaintext file:

```bash
python3 scripts/sqlite_backup.py encrypt backups/fable-2026-10-30.sqlite3 backups/fable-2026-10-30.sqlite3.enc
python3 scripts/sqlite_backup.py verify backups/fable-2026-10-30.sqlite3.enc
```

The `encrypt` command leaves the original file untouched so it can be retained until the encrypted copy has been verified and copied to its durable destination.

### Scheduled backups in Docker Compose

The optional `backup` profile runs the encrypted SQLite backup utility once at startup and then at the configured interval. It removes matching encrypted snapshots and legacy `fable-*.sqlite3` snapshots older than the configured retention window; the default is one day between backups and 30 days of retention.

Set `FABLE_BACKUP_HOST_DIR` in `.env` to a mounted durable location and load `FABLE_BACKUP_ENCRYPTION_KEY_B64` from the secret manager. Ensure that directory exists and is writable only by the container's Fable UID/GID (defaults to `1000:1000`); for example, `sudo install -d -o 1000 -g 1000 -m 0700 /srv/fable/backups`. The backup container has no network access, a read-only root filesystem, and read-only access to the live database. Then start both services:

```bash
docker compose --profile backup up -d --build
docker compose --profile backup logs -f fable-backup
```

The sample `./backups` path is on the application host and is not an off-site backup by itself. Mount a separate durable or off-host filesystem at the configured path and monitor backup logs. If the key is absent or invalid, the service exits without creating plaintext backups. If the destination is unavailable or a backup fails, the service logs the failure and retries within five minutes. Keep `FABLE_BACKUP_INTERVAL_SECONDS` at least 60 and `FABLE_BACKUP_RETENTION_DAYS` at least 1.

For OCI deployment, `deploy/oci` includes a write-once uploader for completed encrypted snapshots, systemd timers for uploads and freshness checks, and optional OCI Notifications failure alerts. Follow [Deploy Fable on OCI](OCI_DEPLOYMENT.md) to scope the instance-principal policy to one private bucket, configure alert delivery, and run a restore drill.

### Versioned image release and rollback

After CI passes on the commit, pushing a `v*` tag runs the backend, Docker/Compose, and iOS verification jobs before publishing the backend image to GitHub Container Registry with both a version tag and source commit SHA tag. The workflow reports the registry digest in its run summary; use that digest for deployments and rollback because tags can be moved. The workflow creates an image artifact; it does not deploy to a hosting provider.

Before upgrading, create and verify a database backup. Then set `FABLE_BACKEND_IMAGE` in `.env` to the new image digest reported by the release workflow, authenticate the host to `ghcr.io` if the package is private, and run:

```bash
docker compose --profile backup pull
docker compose --profile backup up -d --no-build
```

To roll back the application, set `FABLE_BACKEND_IMAGE` to the previous release image digest and run the same pull and `up` commands. Restore the pre-upgrade database backup only if the new version applied a migration that is incompatible with the previous image. Keep schema changes backward compatible where possible and verify the health endpoint plus a known account and story after either deployment or rollback.

## Restore

1. Load the matching `FABLE_BACKUP_ENCRYPTION_KEY_B64` from the deployment secret manager.
2. Stop the backend so no process is writing to the database.
3. Verify the selected encrypted backup with `scripts/sqlite_backup.py verify`.
4. Move the current database file to a timestamped recovery copy.
5. Restore the encrypted backup to the configured `FABLE_DB_PATH`, for example `python3 scripts/sqlite_backup.py restore backups/fable-2026-11-05.sqlite3.enc data/fable.sqlite3`; restore verifies the decrypted SQLite integrity before publishing the file and refuses to overwrite an existing destination.
6. Start the backend and check `/api/v1/health` plus a known account and story.
7. Keep the pre-restore copy until the application data has been confirmed.

Database startup applies additive compatibility changes and versioned migrations transactionally. `PRAGMA user_version` records the applied schema version. Back up the database before deploying a new backend version.

## CI and release configuration

GitHub Actions runs backend tests, builds the Docker image, builds the iOS app, and runs the iOS XCTest target on an iOS Simulator. The CI HTTPS host is only a build validation value; it is not a production deployment endpoint.

## Monitoring and incident response

The image health check calls `/api/v1/health` every 30 seconds after a 20-second startup grace period. That endpoint reports API and database health; it does not confirm provider availability, SMTP delivery, backup freshness, or end-to-end iOS behavior. Check the deployed HTTPS health URL from outside the host and configure the hosting platform to alert on sustained health-check failures, repeated container restarts, and elevated 5xx responses. For OCI, use an HTTPS Health Checks monitor and a Monitoring alarm for the public API, plus the included host freshness timer for local encrypted backup age.

Unexpected 500 responses include an `X-Request-ID` response header. Match that ID with the server log entry, which records the method, path, exception type, and stack frames without logging the exception message or request body. Include the request ID when reporting a server error; do not include passwords, bearer tokens, reset codes, or other credentials in support messages.

For the backup profile, alert when no verified encrypted snapshot has arrived within the backup interval plus the operator's recovery grace period. Review `fable-backup` logs after failures and verify SMTP delivery separately before enabling account recovery. Keep alerts free of tokens, backup keys, and unnecessary user data. Configure hosted monitors, notification recipients, and the on-call owner in the deployment runbook; those account settings cannot be configured from this repository.
