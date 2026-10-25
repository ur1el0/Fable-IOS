#!/bin/bash
set -euo pipefail

if [[ "${CONFIGURATION:-}" != "Release" ]]; then
    exit 0
fi

python3 - "${FABLE_API_BASE_URL:-}" <<'PY'
import ipaddress
import socket
import sys
from urllib.parse import urlsplit

value = sys.argv[1]
try:
    parsed = urlsplit(value)
    parsed.port
except ValueError:
    raise SystemExit("Release builds require a valid API URL.")
host = parsed.hostname

if (
    parsed.scheme != "https"
    or not host
    or parsed.username
    or parsed.password
    or parsed.query
    or parsed.fragment
):
    raise SystemExit("Release builds require FABLE_API_BASE_URL to be an HTTPS URL.")

normalized_host = host.rstrip(".").lower()
if (
    normalized_host == "localhost"
    or normalized_host.endswith((".localhost", ".local", ".test", ".invalid"))
):
    raise SystemExit("Release builds cannot use a local or reserved API host.")

try:
    address = ipaddress.ip_address(normalized_host)
except ValueError:
    try:
        address = ipaddress.ip_address(socket.inet_aton(normalized_host))
    except (OSError, ValueError):
        address = None

if address and (address.is_loopback or address.is_unspecified):
    raise SystemExit("Release builds cannot use a loopback or unspecified API address.")
PY
