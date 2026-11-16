# Wireless iPhone & Fedora Linux / Mac Server Guide

This guide explains how to run the Fable backend with a single command on **Fedora Linux** or **macOS**, retrieve the live backend URL, and connect a physical iPhone running **FableApp** completely wirelessly—without Xcode or a Lightning cable.

---

## 1. One-Command Wireless Backend Launcher

From the repository root on **macOS** or **Fedora Linux**, run:

```bash
./scripts/start_wireless_server.sh
```

What [`scripts/start_wireless_server.sh`](../scripts/start_wireless_server.sh) does automatically:
1. Creates `.venv` and installs `backend/requirements.txt` if not yet installed.
2. Starts FastAPI (`uvicorn main:app --reload --host 0.0.0.0 --port 8001`) with `FABLE_ENV=development` and `FABLE_DB_PATH=backend/fable.sqlite3` (or reuses an already-running backend on port `8001`).
3. Detects your computer's local Wi-Fi / Hotspot IPv4 address.
4. Starts `cloudflared` (installing it to `~/.local/bin/cloudflared` if missing) to create an HTTPS tunnel to your laptop, unless `--no-tunnel` is passed.
5. Prints all ready-to-use URLs in a summary block and cleans up child processes on `Ctrl+C`.

### Flags & Environment Overrides

| Option / Variable | Default | Purpose |
|---|---|---|
| `--tunnel` / `--no-tunnel` | `--tunnel` | Enable or skip the Cloudflare HTTPS tunnel (`FABLE_USE_TUNNEL=0\|1`). |
| `FABLE_BIND_ADDRESS` | `0.0.0.0` | Interface FastAPI binds to (`0.0.0.0` allows wireless devices on LAN/Hotspot). |
| `FABLE_PORT` | `8001` | Port for Uvicorn and the Cloudflare tunnel. |
| `FABLE_ENV` | `development` | Enables development features such as auto-returned `recoveryToken` without SMTP. |
| `FABLE_DB_PATH` | `backend/fable.sqlite3` | SQLite database file path. |
| `CLOUDFLARE_TUNNEL_TOKEN` | *(unset)* | Optional Cloudflare Zero Trust Named Tunnel token for a permanent fixed domain. |

---

## 2. How to Get the URL for Your iPhone

When `./scripts/start_wireless_server.sh` starts, look at the terminal banner it prints:

```text
==================================================================
  Fable Backend is LIVE for Wireless iPhone Connections
==================================================================
  Local Health:          http://127.0.0.1:8001/api/v1/health
  Home Wi-Fi / Hotspot:  http://192.168.1.50:8001/api/v1
  Public HTTPS Tunnel:   https://random-words-here.trycloudflare.com/api/v1
  Render Cloud Fallback: https://fable-api-cbo8.onrender.com/api/v1

  On your iPhone: Welcome ('Server: ... Change') or Settings ->
  Backend Server URL -> paste the URL above -> Save.
  Press Ctrl+C to stop.
==================================================================
```

Which URL should you choose?

| Network Scenario | URL to Use | Notes |
|---|---|---|
| **Home Wi-Fi or iPhone Personal Hotspot** | **Home Wi-Fi / Hotspot** (`http://<LAN_IP>:8001/api/v1`) | Fastest option. Your laptop's local IP stays consistent on that network, so you only enter it once. |
| **Campus Wi-Fi (AP Client Isolation) or Mobile Data** | **Public HTTPS Tunnel** (`https://<id>.trycloudflare.com/api/v1`) | Works across different networks when peer-to-peer LAN access is blocked. Quick tunnel subdomains rotate on restart unless `CLOUDFLARE_TUNNEL_TOKEN` is configured. |
| **No Laptop Running** | **Render Cloud Fallback** (`https://fable-api-cbo8.onrender.com/api/v1`) | Always available online. Note that Render Free blocks outbound SMTP ports (`25`/`465`/`587`), so password-reset emails are unavailable on Render Cloud. |

> [!TIP]
> **Automatic `/api/v1` Normalization:** `StoryAPIService.normalizeBaseURLString` automatically appends `/api/v1` if you enter only the host and port (for example, `http://192.168.1.50:8001` or `https://example.trycloudflare.com`).

---

## 3. Entering the URL Inside FableApp (No Rebuild Required)

You can switch the active backend URL at runtime directly on your iPhone:

1. **Before Signing In (Welcome Screen):**
   - Tap the **`Server: <host> • Change`** pill below *Continue as Guest*.
2. **While Signed In (Settings Screen):**
   - Go to **Shelf ➔ Settings (gear icon) ➔ Backend Server URL**.
3. Choose an action in the **Backend Server URL** alert:
   - **Save Custom URL** / **Save & Sync**: Saves your laptop's LAN or tunnel URL in `UserDefaults` (`fable_custom_api_base_url`).
   - **Use Render Cloud**: Switches to `https://fable-api-cbo8.onrender.com/api/v1`.
   - **Reset to Bundle Default**: Clears the custom override and reverts to `FABLE_API_BASE_URL` from `Info.plist`.

---

## 4. Fedora Linux Specific Notes

### Opening the Local Port for Home Wi-Fi / Hotspot
Fedora enables `firewalld` by default. Allow TCP port `8001` when connecting your iPhone directly to your laptop's **Home Wi-Fi / Hotspot** URL:

```bash
sudo firewall-cmd --add-port=8001/tcp
# Optional: persist across reboots
sudo firewall-cmd --permanent --add-port=8001/tcp
```

*(If you connect via the **Public HTTPS Tunnel** `https://<id>.trycloudflare.com`, opening port `8001` in `firewalld` is not required because `cloudflared` connects outbound.)*

### Refreshing the iOS App Without a Mac (7-Day Personal Team Expiry)
Apple's free Personal Team developer certificates expire every **7 days**. From Fedora Linux:
- Build the `.ipa` artifact in CI (`macos-latest` GitHub Actions runner), then sideload and refresh it over USB or Wi-Fi using **SideStore** or **`altserver-linux`** (`sudo dnf install usbmuxd libimobiledevice`).

---

## 5. Development Password Recovery & Timestamp Compatibility

- **Development Password Reset (`FABLE_ENV=development`):** When SMTP environment variables (`FABLE_SMTP_HOST`, `FABLE_SMTP_FROM_EMAIL`) are unset in `development` mode, `POST /api/v1/auth/password-reset/request` returns a `recoveryToken` in the response payload for existing accounts, which `PasswordRecoveryViewModel` automatically fills into the recovery-code field on iOS. In `staging`/`production`, SMTP configuration remains required and missing SMTP returns HTTP `503`.
- **ISO-8601 Fractional Seconds:** `StoryAPIService.iso8601DateDecodingStrategy` parses both fractional-microsecond UTC timestamps emitted by FastAPI/Pydantic and standard ISO-8601 timestamps.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| **"Offline Cache" or timeout right after unplugging USB** | Phone was pointed to a USB-only tunnel or campus Wi-Fi blocks phone internet | Open **Backend Server URL** on your iPhone and tap **Reset to Bundle Default** (or enter your tunnel/LAN URL). If campus Wi-Fi restricts phones, switch to **Mobile Data** or connect your laptop to your iPhone's **Personal Hotspot**. |
| **"An internet connection is required" when trusting Developer App** | Campus Wi-Fi blocks Apple's `ppq.apple.com` verification on mobile devices | Temporarily switch to **Mobile Data**, go to **Settings ➔ General ➔ VPN & Device Management**, tap **Trust**, then re-enable Wi-Fi. |
| **iPhone cannot connect to `http://<fedora-ip>:8001`** | Fedora firewall blocking `8001`, or router/campus Wi-Fi AP Client Isolation | Run `sudo firewall-cmd --add-port=8001/tcp` on Fedora. If on campus Wi-Fi, use the **Public HTTPS Tunnel** URL instead. |
| **Password reset returns `"The server could not complete the request."`** | Pointed at a stopped tunnel or Render Cloud without SMTP | Run `./scripts/start_wireless_server.sh` (`FABLE_ENV=development`), update **Backend Server URL** to the printed tunnel/LAN URL, and retry **Forgot Password?**. |
