#!/usr/bin/env bash
set -euo pipefail

: "${FABLE_BACKUP_HOST_DIR:?Set FABLE_BACKUP_HOST_DIR to the encrypted backup directory}"
: "${OCI_OBJECT_STORAGE_BUCKET:?Set OCI_OBJECT_STORAGE_BUCKET to a private OCI bucket}"

if ! command -v oci >/dev/null 2>&1; then
  echo "OCI CLI is required on the host to upload backups." >&2
  exit 1
fi

if [[ ! -d "$FABLE_BACKUP_HOST_DIR" ]]; then
  echo "Backup directory does not exist: $FABLE_BACKUP_HOST_DIR" >&2
  exit 1
fi

prefix="${FABLE_BACKUP_OBJECT_PREFIX:-fable}"
prefix="${prefix#/}"
prefix="${prefix%/}"
if [[ ! "$prefix" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ || "$prefix" == *".."* ]]; then
  echo "FABLE_BACKUP_OBJECT_PREFIX must be a simple object prefix." >&2
  exit 1
fi

namespace="${OCI_OBJECT_STORAGE_NAMESPACE:-}"
if [[ -z "$namespace" ]]; then
  namespace="$(oci os ns get --auth instance_principal --query data --raw-output)"
fi
if [[ -z "$namespace" ]]; then
  echo "Unable to determine the OCI Object Storage namespace." >&2
  exit 1
fi

backup_files=()
while IFS= read -r -d '' backup_file; do
  backup_files+=("$backup_file")
done < <(find "$FABLE_BACKUP_HOST_DIR" -maxdepth 1 -type f -name 'fable-*.sqlite3.enc' -print0 | sort -z)

if ((${#backup_files[@]} == 0)); then
  echo "No completed encrypted Fable backups found in $FABLE_BACKUP_HOST_DIR." >&2
  exit 1
fi

for backup_file in "${backup_files[@]}"; do
  object_name="$prefix/$(basename "$backup_file")"
  if oci os object head \
    --auth instance_principal \
    --namespace "$namespace" \
    --bucket-name "$OCI_OBJECT_STORAGE_BUCKET" \
    --name "$object_name" \
    --output json >/dev/null 2>&1; then
    echo "Encrypted backup already exists in Object Storage: $object_name"
    continue
  fi

  echo "Uploading or confirming existing encrypted backup: $object_name"
  oci os object put \
    --auth instance_principal \
    --namespace "$namespace" \
    --bucket-name "$OCI_OBJECT_STORAGE_BUCKET" \
    --name "$object_name" \
    --file "$backup_file" \
    --no-overwrite \
    --verify-checksum \
    --output json >/dev/null
done
