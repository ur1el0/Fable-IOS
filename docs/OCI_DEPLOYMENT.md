# Deploy Fable on OCI

This guide deploys the FastAPI backend on an OCI Compute instance with Caddy handling HTTPS, encrypted SQLite snapshots copied to a private Object Storage bucket, and optional OCI Notifications for failed backup jobs. The repository does not create OCI resources or hold cloud credentials.

## Deployment layout

- Caddy is public on TCP 80 and 443 and obtains and renews the certificate for `FABLE_DOMAIN`.
- FastAPI listens on container port 8000 and is attached only to a private Docker bridge. The base Compose file publishes it on host loopback (`127.0.0.1:8000`), never on a public interface.
- The backup container has no network access. It creates and verifies authenticated-encrypted SQLite snapshots in a host directory.
- A separate host systemd timer uploads only `fable-*.sqlite3.enc` snapshots to OCI Object Storage using the instance principal. It never uploads the database or encryption key.
- A second systemd timer checks local backup freshness and can publish upload or freshness failures to an OCI Notifications topic.

## OCI network and compute

1. Create a VCN with an internet gateway and a **public subnet** with a default route to that gateway. Assign a public IPv4 address to the Compute instance's primary VNIC. OCI's VCN wizard can create the VCN, subnet, gateway, route table, and security list together.
2. Create an ingress rule for TCP 22 from your current public IP with a `/32` mask. Add TCP 80 and 443 from `0.0.0.0/0` so DNS validation and HTTPS traffic can reach Caddy. Add corresponding host firewall services. Do not add public ingress for TCP 8000, SSH from all addresses, or SQLite ports.
3. Launch Oracle Linux 9 on an available shape. Images published by this branch's release workflow support both `linux/amd64` and `linux/arm64`, so either x86 or Ampere can run the backend image after a new release is published. OCI capacity varies by region and availability domain; if creation reports out of capacity, try another availability domain or region, or retry later.
4. Point an `A` record for the API hostname (for example, `api.example.com`) at the instance's public IPv4 address. Wait for DNS to resolve before starting Caddy; it needs public DNS and inbound TCP 80/443 to obtain a certificate.

OCI creates a public subnet route and internet gateway as separate resources; a public IP alone does not make an instance reachable unless the route and security rules permit traffic. See the [VCN quickstart](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/quickstartnetworking.htm), [internet gateway guide](https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingIGs.htm), and [out-of-capacity guide](https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/troubleshooting-out-of-host-capacity.htm).

## Prepare the host

Install Docker Engine with the Compose plugin and the OCI CLI using their official installation guides. Install the OCI CLI so `oci` is on the systemd service's `PATH` (`/usr/local/bin:/usr/bin:/bin`). Do not configure an API-key profile for the uploader; it uses an instance principal.

Check out the reviewed release on the instance under `/opt/fable`, then configure the application:

```bash
cd /opt/fable
cp .env.example .env
```

Edit `.env` and set at least:

- `FABLE_ENV=production`
- `FABLE_DOMAIN` to the DNS name pointing at this instance
- `FABLE_BACKEND_IMAGE` to a published GHCR version tag or, preferably, the immutable digest from the release workflow
- `FABLE_BIND_ADDRESS=127.0.0.1`
- `FABLE_BACKUP_HOST_DIR=/srv/fable/backups`
- `FABLE_BACKUP_ENCRYPTION_KEY_B64` from a secret manager, using a generated 32-byte key as described in [Backend Operations](OPERATIONS.md#sqlite-backup)
- `FABLE_INGESTION_API_KEY` and any required SMTP settings

Create the backup directory with the configured container UID/GID (the sample defaults to `1000:1000`):

```bash
sudo install -d -o 1000 -g 1000 -m 0700 /srv/fable/backups
```

Verify the rendered Compose configuration and pull the selected image:

```bash
docker compose -f docker-compose.yml -f docker-compose.production.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.production.yml pull
docker compose -f docker-compose.yml -f docker-compose.production.yml up -d --no-build
```

Review logs and confirm `https://<FABLE_DOMAIN>/api/v1/health` returns healthy. Caddy's first certificate request can take a short time. If it fails, check DNS, TCP 80/443 ingress, and Caddy logs. Keep host firewalld rules and OCI security lists aligned; permit SSH only from a trusted source and HTTP/HTTPS publicly.

## Encrypted off-host backups

Create a **private** Object Storage bucket dedicated to Fable backups. Keep the bucket in the compartment used by the policy below. Configure an Object Lifecycle Management rule to delete the backup prefix after the approved retention period; keep it at least as long as local retention and the recovery period you need. The uploader uses write-once object creation, so it cannot overwrite an existing object or delete expired objects.

Create an OCI dynamic group that matches only this Compute instance. A rule matching the instance OCID is narrower than including every instance in the compartment:

```text
instance.id = '<FABLE_INSTANCE_OCID>'
```

Create a policy in the tenancy (replace the compartment, bucket, prefix, and dynamic-group names):

```text
Allow dynamic-group FableBackupUploader to manage objects in compartment FableDeployment where all {target.bucket.name='fable-backups', target.object.name='fable/*', any {request.permission='OBJECT_CREATE', request.permission='OBJECT_INSPECT'}}
Allow dynamic-group FableBackupUploader to use ons-topics in compartment FableDeployment
```

The first statement permits write-once uploads and object metadata checks only under the named bucket and prefix. The second is optional and permits publishing alerts to Notifications topics in that compartment; keep only the dedicated alert topic there. Instance principals use the instance's OCI identity instead of distributing API keys to the host. Review [calling OCI services from instances](https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm), [Object Storage policy examples](https://docs.oracle.com/en-us/iaas/Content/Security/Reference/objectstorage_security.htm), and [Notifications policy permissions](https://docs.oracle.com/en-us/iaas/Content/Identity/policyreference/notificationpolicyreference.htm).

Copy the uploader settings template to a root-controlled file and fill in the namespace, bucket, optional alert topic OCID, and backup path:

```bash
sudo install -d -m 0750 /etc/fable
sudo install -o root -g root -m 0640 deploy/oci/backup-upload.env.example /etc/fable/backup-upload.env
sudoedit /etc/fable/backup-upload.env
```

The unit files assume the repository is at `/opt/fable`, the backup directory is `/srv/fable/backups`, and the uploader runs as UID/GID `1000:1000`. If using different paths or IDs, update the unit files and directory ownership together.

Start encrypted backups and enable the host upload/freshness timers:

```bash
docker compose --profile backup -f docker-compose.yml -f docker-compose.production.yml up -d --no-build
sudo install -m 0644 deploy/oci/fable-backup-upload.service /etc/systemd/system/
sudo install -m 0644 deploy/oci/fable-backup-upload.timer /etc/systemd/system/
sudo install -m 0644 deploy/oci/fable-backup-health.service /etc/systemd/system/
sudo install -m 0644 deploy/oci/fable-backup-health.timer /etc/systemd/system/
sudo install -m 0644 'deploy/oci/fable-backup-alert@.service' /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl start fable-backup-upload.service
sudo systemctl enable --now fable-backup-upload.timer fable-backup-health.timer
```

The upload service runs once immediately; its timer retries hourly. The freshness timer checks every 15 minutes against `FABLE_BACKUP_HEALTH_MAX_AGE_SECONDS` (default 26 hours). A failure is recorded in the systemd journal. Set `OCI_BACKUP_ALERT_TOPIC_OCID` in `/etc/fable/backup-upload.env` and create/confirm an email or other subscription on that Notifications topic to receive failure messages. Confirm delivery by publishing a test message from OCI Console after subscription confirmation. The supplied alert contains only the failed unit and host name.

Inspect service and timer state with:

```bash
sudo systemctl status fable-backup-upload.timer fable-backup-health.timer
sudo journalctl -u fable-backup-upload.service -u fable-backup-health.service --since today
docker compose --profile backup -f docker-compose.yml -f docker-compose.production.yml ps
```

To restore from Object Storage, download the encrypted file first; never put the key in the download command or object metadata:

```bash
set -a
source /etc/fable/backup-upload.env
set +a
oci os object get --auth instance_principal --namespace "$OCI_OBJECT_STORAGE_NAMESPACE" \
  --bucket-name "$OCI_OBJECT_STORAGE_BUCKET" --name "fable/<backup-file>.sqlite3.enc" \
  --file /tmp/fable-restore.sqlite3.enc
FABLE_BACKUP_ENCRYPTION_KEY_B64='<load-from-secret-manager>' \
  python3 scripts/sqlite_backup.py restore /tmp/fable-restore.sqlite3.enc /tmp/fable-restore.sqlite3
```

Complete a restore drill to a temporary path before relying on the deployment. See [Backend Operations: Restore](OPERATIONS.md#restore) for replacing the live database safely. Check the current Object Storage quotas and expected snapshot size before relying on Always Free storage.

## HTTPS and alert monitoring

Configure an OCI Health Checks HTTP monitor after the domain resolves:

- Target: the API DNS hostname (not its IP), protocol HTTPS, port 443
- Method: GET
- Path: `/api/v1/health`
- Interval: 30 seconds or longer
- Vantage points: select at least three locations if available

Then create an OCI Monitoring alarm from the Health Checks availability metric and send it to a Notifications topic with a confirmed subscription. This checks the API from outside the instance, including DNS, TLS, and network reachability. OCI Health Checks supports public HTTP/HTTPS endpoints; use the alarm workflow for notifications. See [Health Checks overview](https://docs.oracle.com/en-us/iaas/Content/HealthChecks/Concepts/healthchecks.htm), [creating an HTTPS monitor](https://docs.oracle.com/en-us/iaas/Content/HealthChecks/Tasks/create-http-monitor.htm), and [creating a Monitoring alarm](https://docs.oracle.com/en-us/iaas/Content/Monitoring/Tasks/create-alarm-basic.htm).

The host freshness timer covers the backup signal that the public API health endpoint cannot see. Alert if the upload service fails, a recent encrypted snapshot is missing, the HTTPS health check fails, or the Compute instance repeatedly restarts. Keep notification messages free of passwords, API keys, backup encryption keys, and user content.

## Remaining operator setup

- Obtain an instance in an available region/shape and create its VCN, public subnet, routes, security rules, and public IPv4 address.
- Add DNS and configure the OCI security list/NSG and host firewall as above.
- Install Docker Compose and OCI CLI; create the private bucket, dynamic group, scoped policy, and (if desired) Notifications topic/subscription.
- Set application secrets and the backup key locally; never commit `.env` or `/etc/fable/backup-upload.env`.
- Set the production `FABLE_API_BASE_URL` Xcode build setting to `https://<FABLE_DOMAIN>/api/v1` for Release builds.
- Perform the first HTTPS check, confirm a backup object appears in the bucket, verify alert delivery, and complete a restore drill.
