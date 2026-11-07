#!/usr/bin/env bash
set -euo pipefail

failed_unit="${1:-unknown backup job}"
topic_id="${OCI_BACKUP_ALERT_TOPIC_OCID:-}"

if [[ -z "$topic_id" ]]; then
  echo "OCI backup notification skipped: OCI_BACKUP_ALERT_TOPIC_OCID is not configured (failed unit: $failed_unit)." >&2
  exit 0
fi

if ! command -v oci >/dev/null 2>&1; then
  echo "OCI CLI is required to publish backup failure notifications." >&2
  exit 1
fi

host="$(hostname -f 2>/dev/null || hostname)"
body="Fable backup operation '$failed_unit' failed on $host at $(date -u +%Y-%m-%dT%H:%M:%SZ). Check the systemd journal and backup directory."

oci ons message publish \
  --auth instance_principal \
  --topic-id "$topic_id" \
  --title "Fable backup operation failed" \
  --body "$body" \
  --output json >/dev/null
