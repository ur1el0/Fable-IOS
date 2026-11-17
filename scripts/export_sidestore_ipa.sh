#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/frontend/FableApp.xcodeproj"
ARCHIVE_PATH="$REPO_ROOT/build/sidestore/FableApp.xcarchive"
IPA_OUTPUT="$REPO_ROOT/build/sidestore/FableApp.ipa"
STAGE_DIR="$REPO_ROOT/build/sidestore/ipa_stage"

API_BASE_URL="${FABLE_API_BASE_URL:-https://fable-api-cbo8.onrender.com/api/v1}"
TEAM_ID="${FABLE_DEVELOPMENT_TEAM:-9VQCMTR4F8}"
DEVICE_ID="${FABLE_DEVICE_ID:-}"
SIDESTORE_BUNDLE_ID="${FABLE_SIDESTORE_BUNDLE_ID:-}"
COPY_TO_DEVICE=1
INSTALL_DIRECT=0
OPEN_SIDESTORE=1

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Builds a Release iOS archive of FableApp, packages it as an .ipa for SideStore,
and copies FableApp.ipa into SideStore's Documents folder on a connected iPhone.

Options:
  --device <id>         CoreDevice identifier, UDID, or name (auto-detected if omitted)
  --api-url <url>       Release HTTPS API URL (default: $API_BASE_URL)
  --team-id <id>        Apple Development Team ID (default: $TEAM_ID)
  --install-direct      Also install FableApp.app directly via devicectl
  --no-open-sidestore   Do not launch SideStore after copying FableApp.ipa
  --no-copy             Only build build/sidestore/FableApp.ipa locally
  -h, --help            Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)
      DEVICE_ID="${2:-}"
      shift 2
      ;;
    --api-url)
      API_BASE_URL="${2:-}"
      shift 2
      ;;
    --team-id)
      TEAM_ID="${2:-}"
      shift 2
      ;;
    --install-direct)
      INSTALL_DIRECT=1
      shift
      ;;
    --no-open-sidestore)
      OPEN_SIDESTORE=0
      shift
      ;;
    --no-copy)
      COPY_TO_DEVICE=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[fable] Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

echo "[fable] Validating Release API URL: $API_BASE_URL"
CONFIGURATION=Release FABLE_API_BASE_URL="$API_BASE_URL" "$REPO_ROOT/scripts/validate_ios_release_config.sh"

if [[ "$COPY_TO_DEVICE" -eq 1 || "$INSTALL_DIRECT" -eq 1 ]]; then
  if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(xcrun devicectl list devices 2>/dev/null | awk 'NR>2 && $0 ~ /available/ { for (i=1; i<=NF; i++) if ($i ~ /^[0-9A-F-]{36}$/) { print $i; exit } }')"
  fi
  if [[ -z "$DEVICE_ID" ]]; then
    echo "[fable] No paired iOS device found via xcrun devicectl list devices." >&2
    exit 1
  fi
  echo "[fable] Target device: $DEVICE_ID"

  if [[ "$COPY_TO_DEVICE" -eq 1 && -z "$SIDESTORE_BUNDLE_ID" ]]; then
    SIDESTORE_BUNDLE_ID="$(xcrun devicectl device info apps --device "$DEVICE_ID" 2>/dev/null | awk '/com\.SideStore\.SideStore/ { for (i=1; i<=NF; i++) if ($i ~ /^com\.SideStore\.SideStore/) { print $i; exit } }')"
  fi
fi

mkdir -p "$REPO_ROOT/build/sidestore"
rm -rf "$ARCHIVE_PATH" "$STAGE_DIR" "$IPA_OUTPUT"

echo "[fable] Archiving Release build for generic/platform=iOS (Team: $TEAM_ID)..."
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme FableApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  FABLE_API_BASE_URL="$API_BASE_URL" \
  -allowProvisioningUpdates

APP_PATH="$ARCHIVE_PATH/Products/Applications/FableApp.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "[fable] Expected app bundle missing at $APP_PATH" >&2
  exit 1
fi

echo "[fable] Packaging $IPA_OUTPUT..."
mkdir -p "$STAGE_DIR/Payload"
cp -R "$APP_PATH" "$STAGE_DIR/Payload/FableApp.app"
(cd "$STAGE_DIR" && zip -qry "$IPA_OUTPUT" Payload)
rm -rf "$STAGE_DIR"

echo "[fable] Exported IPA: $IPA_OUTPUT ($(du -h "$IPA_OUTPUT" | awk '{print $1}'))"

if [[ "$COPY_TO_DEVICE" -eq 1 ]]; then
  if [[ -n "$SIDESTORE_BUNDLE_ID" ]]; then
    echo "[fable] Copying FableApp.ipa to $SIDESTORE_BUNDLE_ID (Documents/FableApp.ipa)..."
    xcrun devicectl device copy to \
      --device "$DEVICE_ID" \
      --domain-type appDataContainer \
      --domain-identifier "$SIDESTORE_BUNDLE_ID" \
      --source "$IPA_OUTPUT" \
      --destination Documents/FableApp.ipa

    if [[ "$OPEN_SIDESTORE" -eq 1 ]]; then
      echo "[fable] Launching SideStore ($SIDESTORE_BUNDLE_ID) on device..."
      xcrun devicectl device process launch --device "$DEVICE_ID" "$SIDESTORE_BUNDLE_ID" || true
    fi
  else
    echo "[fable] SideStore was not found on device $DEVICE_ID; skipped container copy." >&2
  fi
fi

if [[ "$INSTALL_DIRECT" -eq 1 ]]; then
  echo "[fable] Installing FableApp.app directly onto device $DEVICE_ID..."
  xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
fi

cat <<EOF

[fable] Done.
  IPA on Mac:    $IPA_OUTPUT
  Phone Path:    On My iPhone -> SideStore -> FableApp.ipa

To keep FableApp managed by SideStore (auto-refreshed so it does not expire):
  1. Turn on your SideStore VPN (e.g. StosVPN) and ensure SideStore is signed in.
  2. Open SideStore -> My Apps -> '+' -> select FableApp.ipa.
EOF
