# Backend Operations

## Deployment boundary

The backend container serves plain HTTP on port 8000. In production, place it behind a TLS-terminating reverse proxy or managed ingress. Keep port 8000 private to that proxy. The checked-in Compose file binds it to loopback by default; set `FABLE_BIND_ADDRESS=0.0.0.0` only for a trusted development LAN.

Uvicorn's proxy middleware only accepts forwarded headers from peers listed in `FORWARDED_ALLOW_IPS`. Set that variable to the reverse-proxy source IP addresses or networks for the deployment; do not use `*`. The proxy must replace incoming `X-Forwarded-For` values with the observed client address. Fable's application middleware ignores raw forwarded headers and uses the ASGI client address, so an untrusted header cannot change a rate-limit bucket. If the proxy address is not trusted, clients will share the proxy's rate-limit bucket.

Set `FABLE_ENV=production` and provide the allowed browser origins in `FABLE_CORS_ORIGINS` as a JSON array (`CORS_ORIGINS` is accepted as a compatibility alias). Native iOS requests do not require a browser origin. Production startup rejects wildcard CORS origins.

Authentication endpoints use SQLite-backed per-IP and per-account/IP limits. Defaults are 5 registrations and 60 login attempts per IP per 15 minutes, plus 10 login attempts per account/IP per window. Tune `FABLE_AUTH_RATE_WINDOW_SECONDS`, `FABLE_AUTH_REGISTER_LIMIT_PER_IP`, `FABLE_AUTH_LOGIN_LIMIT_PER_IP`, and `FABLE_AUTH_LOGIN_LIMIT_PER_ACCOUNT_IP` for the deployment. The limits use the ASGI client address; configure a trusted proxy so that address reflects the client IP without accepting untrusted forwarded headers. Request bodies default to 256 KiB and can be adjusted with `FABLE_MAX_REQUEST_BODY_BYTES`.

The in-memory rate limiter stores at most `FABLE_RATE_LIMIT_MAX_CLIENT_BUCKETS` client/tier buckets (default 10,000). Authentication and provider ingestion use its stricter auth tier; tune `RATE_LIMIT_AUTH_LIMIT` and `RATE_LIMIT_AUTH_WINDOW` if needed. At capacity it prunes expired buckets and temporarily rejects new client keys if all retained buckets are active. The limit is process-local; deployments with multiple workers should also enforce request limits at the edge.

## Provider ingestion and resource limits

The provider ingestion routes write live Gutenberg and MangaDex content into SQLite and require the operator-only `X-Fable-Ingestion-Key` header. Set `FABLE_INGESTION_API_KEY` from a secret manager to a random value with at least 32 bytes of entropy. For example, generate 32 random bytes as hexadecimal with `python3 -c 'import secrets; print(secrets.token_hex(32))'`. If the key is missing or shorter than 32 bytes, ingestion fails closed with HTTP 503; a missing or incorrect request key returns HTTP 401. Never place this key in the iOS app or a public client.

Provider work has fixed process limits: Gutenberg text downloads are streamed and capped at 8 MiB, chapter fetches run at most three concurrently, and its chapter cache holds at most 32 entries / 16 MiB for 10 minutes. Manga provider responses are streamed and capped at 2 MiB, upstream calls run at most five concurrently, and its LRU cache holds at most 128 entries / 16 MiB for 10 minutes. These limits are intentionally enforced in the service layer rather than exposed as per-request controls.

For iOS Release builds, set the Xcode build setting `FABLE_API_BASE_URL` to the deployed HTTPS API root, for example `https://api.example.com/api/v1`, replacing the example host with the deployed host. Release builds fail when the value is missing, is not HTTPS, or uses a loopback, unspecified, or reserved local host. Debug builds retain the simulator URL.

## SQLite backup

Create an online, transactionally consistent backup with Python's SQLite backup API:

```bash
python3 scripts/sqlite_backup.py backup data/fable.sqlite3 backups/fable-YYYY-MM-DD.sqlite3
python3 scripts/sqlite_backup.py verify backups/fable-YYYY-MM-DD.sqlite3
```

Use the actual path configured by `FABLE_DB_PATH` if it differs. Store backups outside the application data directory and restrict access to them. The scheduled Compose service can maintain a host-mounted snapshot history; the hosting operator must mount durable off-host storage at that path for disaster recovery.

### Scheduled backups in Docker Compose

The optional `backup` profile runs the same verified SQLite backup utility once at startup and then at the configured interval. It removes matching `fable-*.sqlite3` snapshots older than the configured retention window; the default is one day between backups and 30 days of retention.

Set `FABLE_BACKUP_HOST_DIR` in `.env` to a mounted durable location. Ensure that directory exists and is writable only by the container's Fable UID/GID (defaults to `1000:1000`); for example, `sudo install -d -o 1000 -g 1000 -m 0700 /srv/fable/backups`. The backup container has no network access, a read-only root filesystem, and read-only access to the live database. Then start both services:

```bash
docker compose --profile backup up -d --build
docker compose --profile backup logs -f fable-backup
```

The sample `./backups` path is on the application host and is not an off-site backup by itself. Mount a separate durable or off-host filesystem at the configured path and monitor backup logs. If the destination is unavailable or a backup fails, the service logs the failure and retries within five minutes. Keep `FABLE_BACKUP_INTERVAL_SECONDS` at least 60 and `FABLE_BACKUP_RETENTION_DAYS` at least 1.

### Versioned image release and rollback

After CI passes on the commit, pushing a `v*` tag runs the backend, Docker/Compose, and iOS verification jobs before publishing the backend image to GitHub Container Registry with both a version tag and source commit SHA tag. The workflow reports the registry digest in its run summary; use that digest for deployments and rollback because tags can be moved. The workflow creates an image artifact; it does not deploy to a hosting provider.

Before upgrading, create and verify a database backup. Then set `FABLE_BACKEND_IMAGE` in `.env` to the new image digest reported by the release workflow, authenticate the host to `ghcr.io` if the package is private, and run:

```bash
docker compose --profile backup pull
docker compose --profile backup up -d --no-build
```

To roll back the application, set `FABLE_BACKEND_IMAGE` to the previous release image digest and run the same pull and `up` commands. Restore the pre-upgrade database backup only if the new version applied a migration that is incompatible with the previous image. Keep schema changes backward compatible where possible and verify the health endpoint plus a known account and story after either deployment or rollback.

## Restore

1. Stop the backend so no process is writing to the database.
2. Verify the selected backup with `scripts/sqlite_backup.py verify`.
3. Move the current database file to a timestamped recovery copy.
4. Copy the verified backup into the configured `FABLE_DB_PATH` location.
5. Start the backend and check `/api/v1/health` plus a known account and story.
6. Keep the pre-restore copy until the application data has been confirmed.

Database startup applies additive compatibility changes and versioned migrations transactionally. `PRAGMA user_version` records the applied schema version. Back up the database before deploying a new backend version.

## CI and release configuration

GitHub Actions runs backend tests, builds the Docker image, builds the iOS app, and runs the iOS XCTest target on an iOS Simulator. The CI HTTPS host is only a build validation value; it is not a production deployment endpoint.
