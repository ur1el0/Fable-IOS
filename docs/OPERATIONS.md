# Backend Operations

## Deployment boundary

The backend container serves plain HTTP on port 8000. In production, place it behind a TLS-terminating reverse proxy or managed ingress. Keep port 8000 private to that proxy. The checked-in Compose file binds it to loopback by default; set `FABLE_BIND_ADDRESS=0.0.0.0` only for a trusted development LAN.

Set `FABLE_ENV=production` and provide the allowed browser origins in `CORS_ORIGINS` as a JSON array. Native iOS requests do not require a browser origin. Production startup rejects wildcard CORS origins.

Authentication endpoints use SQLite-backed per-IP and per-account/IP limits. Defaults are 5 registrations and 60 login attempts per IP per 15 minutes, plus 10 login attempts per account/IP per window. Tune `FABLE_AUTH_RATE_WINDOW_SECONDS`, `FABLE_AUTH_REGISTER_LIMIT_PER_IP`, `FABLE_AUTH_LOGIN_LIMIT_PER_IP`, and `FABLE_AUTH_LOGIN_LIMIT_PER_ACCOUNT_IP` for the deployment. The limits use the ASGI client address; configure a trusted proxy so that address reflects the client IP without accepting untrusted forwarded headers. Request bodies default to 256 KiB and can be adjusted with `FABLE_MAX_REQUEST_BODY_BYTES`.

For iOS Release builds, set the Xcode build setting `FABLE_API_BASE_URL` to the deployed HTTPS API root, for example `https://api.example.com/api/v1`, replacing the example host with the deployed host. Release builds fail when the value is missing, is not HTTPS, or uses a loopback, unspecified, or reserved local host. Debug builds retain the simulator URL.

## SQLite backup

Create an online, transactionally consistent backup with Python's SQLite backup API:

```bash
python3 scripts/sqlite_backup.py backup data/fable.sqlite3 backups/fable-YYYY-MM-DD.sqlite3
python3 scripts/sqlite_backup.py verify backups/fable-YYYY-MM-DD.sqlite3
```

Use the actual path configured by `FABLE_DB_PATH` if it differs. Store backups outside the application data directory, restrict access to them, and copy them to durable storage. This repository does not configure scheduled off-host backups or retention; the hosting operator must provide those.

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
