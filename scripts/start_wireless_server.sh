#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
VENV_DIR="$REPO_ROOT/.venv"
HOST="${FABLE_BIND_ADDRESS:-0.0.0.0}"
PORT="${FABLE_PORT:-8001}"
ENV_MODE="${FABLE_ENV:-development}"
DB_PATH="${FABLE_DB_PATH:-$BACKEND_DIR/fable.sqlite3}"
USE_TUNNEL="${FABLE_USE_TUNNEL:-1}"

for arg in "$@"; do
  case "$arg" in
    --no-tunnel) USE_TUNNEL=0 ;;
    --tunnel) USE_TUNNEL=1 ;;
    -h|--help)
      cat <<EOF
Usage: $(basename "$0") [--tunnel | --no-tunnel]

Starts the Fable FastAPI backend (bound to 0.0.0.0:$PORT) and, by default,
a Cloudflare HTTPS tunnel so an unplugged iPhone can connect wirelessly from
either home Wi-Fi/Hotspot or campus/mobile networks.
EOF
      exit 0
      ;;
  esac
done

UVICORN_PID=""
TUNNEL_PID=""
SLEEP_PID=""
TUNNEL_LOG=""

cleanup() {
  if [[ -n "$SLEEP_PID" ]] && kill -0 "$SLEEP_PID" 2>/dev/null; then
    kill "$SLEEP_PID" 2>/dev/null || true
  fi
  if [[ -n "$TUNNEL_PID" ]] && kill -0 "$TUNNEL_PID" 2>/dev/null; then
    kill "$TUNNEL_PID" 2>/dev/null || true
  fi
  if [[ -n "$UVICORN_PID" ]] && kill -0 "$UVICORN_PID" 2>/dev/null; then
    kill "$UVICORN_PID" 2>/dev/null || true
  fi
  if [[ -n "$TUNNEL_LOG" && -f "$TUNNEL_LOG" ]]; then
    rm -f "$TUNNEL_LOG"
  fi
}
trap cleanup EXIT INT TERM

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "[fable] Creating Python virtual environment at $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
fi

if [[ ! -x "$VENV_DIR/bin/uvicorn" ]]; then
  echo "[fable] Installing backend dependencies..."
  "$VENV_DIR/bin/pip" install --quiet -r "$BACKEND_DIR/requirements.txt"
fi

detect_lan_ip() {
  local ip=""
  if command -v ipconfig >/dev/null 2>&1; then
    for iface in en0 en1 en2 bridge100; do
      ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
      if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
      fi
    done
  fi
  if command -v ip >/dev/null 2>&1; then
    ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}' | head -n1 || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi
  if command -v hostname >/dev/null 2>&1; then
    ip="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi
  echo "127.0.0.1"
}

find_or_install_cloudflared() {
  if command -v cloudflared >/dev/null 2>&1; then
    command -v cloudflared
    return 0
  fi
  for candidate in /tmp/cloudflared "$HOME/.local/bin/cloudflared"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  local os arch url target="$HOME/.local/bin/cloudflared"
  os="$(uname -s)"
  arch="$(uname -m)"
  mkdir -p "$HOME/.local/bin"

  if [[ "$os" == "Darwin" ]]; then
    if [[ "$arch" == "arm64" ]]; then
      url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-arm64.tgz"
    else
      url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-darwin-amd64.tgz"
    fi
    echo "[fable] Downloading cloudflared for macOS ($arch)..." >&2
    curl -fsSL "$url" | tar -xz -C "$HOME/.local/bin"
    chmod +x "$target"
    echo "$target"
    return 0
  elif [[ "$os" == "Linux" ]]; then
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
      url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64"
    else
      url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
    fi
    echo "[fable] Downloading cloudflared for Linux ($arch)..." >&2
    curl -fsSL "$url" -o "$target"
    chmod +x "$target"
    echo "$target"
    return 0
  fi
  return 1
}

if curl -fsS -m 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
  echo "[fable] Backend already running on port $PORT."
else
  echo "[fable] Starting FastAPI backend on $HOST:$PORT (FABLE_ENV=$ENV_MODE)..."
  (
    cd "$BACKEND_DIR"
    exec env FABLE_ENV="$ENV_MODE" FABLE_DB_PATH="$DB_PATH" \
      "$VENV_DIR/bin/uvicorn" main:app --reload --host "$HOST" --port "$PORT"
  ) &
  UVICORN_PID=$!

  for _ in $(seq 1 30); do
    if curl -fsS -m 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
      break
    fi
    sleep 0.5
  done
  if ! curl -fsS -m 2 "http://127.0.0.1:$PORT/api/v1/health" >/dev/null 2>&1; then
    echo "[fable] Error: Backend failed to respond on http://127.0.0.1:$PORT/api/v1/health" >&2
    exit 1
  fi
fi

LAN_IP="$(detect_lan_ip)"
TUNNEL_URL=""

if [[ "$USE_TUNNEL" == "1" ]]; then
  if CLOUDFLARED_BIN="$(find_or_install_cloudflared 2>/dev/null)"; then
    if [[ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]]; then
      echo "[fable] Starting configured Cloudflare Named Tunnel..."
      "$CLOUDFLARED_BIN" tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" >/dev/null 2>&1 &
      TUNNEL_PID=$!
    else
      TUNNEL_LOG="$(mktemp)"
      "$CLOUDFLARED_BIN" tunnel --no-autoupdate --url "http://127.0.0.1:$PORT" >"$TUNNEL_LOG" 2>&1 &
      TUNNEL_PID=$!
      for _ in $(seq 1 30); do
        TUNNEL_URL="$(grep -Eo 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$TUNNEL_LOG" | head -n1 || true)"
        if [[ -n "$TUNNEL_URL" ]]; then
          break
        fi
        sleep 0.5
      done
    fi
  else
    echo "[fable] Note: cloudflared not available; continuing with LAN server only."
  fi
fi

echo ""
echo "=================================================================="
echo "  Fable Backend is LIVE for Wireless iPhone Connections"
echo "=================================================================="
echo "  Local Health:          http://127.0.0.1:$PORT/api/v1/health"
echo "  Home Wi-Fi / Hotspot:  http://$LAN_IP:$PORT/api/v1"
if [[ -n "$TUNNEL_URL" ]]; then
  echo "  Public HTTPS Tunnel:   $TUNNEL_URL/api/v1"
fi
echo "  Render Cloud Fallback: https://fable-api-cbo8.onrender.com/api/v1"
echo ""
echo "  On your iPhone: Welcome ('Server: ... Change') or Settings ->"
echo "  Backend Server URL -> paste the URL above -> Save."
if [[ "$(uname -s)" == "Linux" ]]; then
  echo "  Fedora LAN firewall tip: sudo firewall-cmd --add-port=$PORT/tcp"
fi
echo "  Press Ctrl+C to stop."
echo "=================================================================="
echo ""

if [[ -n "$TUNNEL_PID" || -n "$UVICORN_PID" ]]; then
  wait
else
  echo "[fable] Press Ctrl+C to exit."
  while true; do
    sleep 60 &
    SLEEP_PID=$!
    wait "$SLEEP_PID" || break
  done
fi
