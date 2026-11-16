# FABLE: Mac Lab Environment Runbook & Reproducibility Guide

**Target Environment:** Academic Mac Lab Computers (macOS Sonoma / Sequoia, Xcode 15/16)  
**Target Hardware:** Apple Silicon / Intel iMacs or Mac Minis in School Labs  
**Target Objective:** Reproducible clone, build, and verification on a shared lab Mac, with live-service checks before production release

---

## 1. Golden Rules for Shared Mac Lab Machines

Shared campus computers have unique quirks: shared user profiles, stale build caches from other students, restricted network access, and permission resets on reboot. Follow these principles to avoid common traps:

1. **Clone to a Local User Directory:** Always clone into `~/Desktop` or `~/Documents` (avoid network-mounted shared drives which cause Xcode file-lock errors).
2. **Never Save GitHub Credentials in Lab Keychain:** Avoid `git config --global credential.helper store`. Use temporary in-memory credential caching instead.
3. **Always Verify Destination is an iOS Simulator:** Xcode on lab machines often defaults to *"My Mac (Mac Catalyst)"*, which will fail to compile iOS-only SwiftUI components. Always switch to **iPhone 16 Pro** or **iPhone 15 Pro**.
4. **Offline Reading:** Previously cached stories remain available without a network connection. Authentication, cloud synchronization, and uncached live catalogs require the configured backend and provider services.

---

## 2. Step-by-Step Setup Procedure on Any Lab Mac

### Step 1: Open Terminal and Clone
```bash
cd ~/Desktop
git clone https://github.com/ur1el0/Fable-IOS.git
cd Fable-IOS
```

### Step 1a: Start the API
From the repository root, start the local backend before launching the app:
```bash
cp .env.example .env
docker compose up -d --build
curl http://127.0.0.1:8001/api/v1/health
```
The Docker container listens on port `8000`; Compose publishes it locally on `8001`. The iOS Debug build defaults to `http://127.0.0.1:8001/api/v1`.

### Step 2: Open Directly in Xcode
Run the following command in Terminal:
```bash
open frontend/FableApp.xcodeproj
```
*Alternatively:* Open **Xcode** ➔ **File** ➔ **Open...** ➔ Select `frontend/FableApp.xcodeproj`.

### Step 3: Verify Xcode Scheme & Destination
Look at the top center of the Xcode window:
- **Left Dropdown (Scheme):** Must show `FableApp`.
- **Right Dropdown (Destination):** Click it and choose **iOS Simulators ➔ iPhone 16 Pro** (or **iPhone 15 Pro**).
  > **Crucial:** If it says *"My Mac"*, Xcode is trying to build for macOS. Change it to an **iPhone Simulator**.

### Step 4: Clean & Build
Before running, clear any potential cache conflicts from previous students:
- Press `Shift + Cmd + K` (**Product ➔ Clean Build Folder**).
- Press `Cmd + B` (**Product ➔ Build**).
- **Expected Result:** Status bar displays **"Build Succeeded"** with **0 Errors**.

### Step 5: Launch on Simulator
- Press `Cmd + R` (**Product ➔ Run**).
- The Simulator will launch and display the Library. The catalog loads live Gutenberg metadata and official covers; full text is fetched from the chapter endpoint when a book is opened. Without network access, expect a previously cached library or an empty state.

### Step 5b: Running on a Physical iPhone (USB & Wireless Local Backend)
1. **Connect iPhone via Lightning / USB-C** and verify Xcode/CoreDevice sees it:
   ```bash
   xcrun devicectl list devices
   ```
2. **Choose how your iPhone will reach the Backend API:**
   - **Option A — Home Wi-Fi or iPhone Personal Hotspot (Direct LAN):**
     Start FastAPI bound to `0.0.0.0`:
     ```bash
     cd backend
     FABLE_ENV=development ../.venv/bin/uvicorn main:app --reload --host 0.0.0.0 --port 8001
     ```
     Use your Mac's Wi-Fi IP (`http://<mac-lan-ip>:8001/api/v1`) as `FABLE_API_BASE_URL`.
   - **Option B — Campus Lab Wi-Fi with AP Client Isolation (Wireless Tunnel to Local Backend):**
     Campus Wi-Fi routers (`172.22.x.x`) isolate wireless clients from connecting directly to each other's local IP. To use your Mac's local FastAPI server wirelessly from your iPhone, start a free SSH HTTPS tunnel in a second terminal:
     ```bash
     ssh -T -o ServerAliveInterval=30 -R 80:127.0.0.1:8001 nokey@localhost.run
     ```
     Copy the printed `https://<id>.app.lhr.life` address and set `FABLE_API_BASE_URL="https://<id>.app.lhr.life/api/v1"`.
   - **Option C — Deployed Cloud Backend (Render + Neon):**
     Set `FABLE_API_BASE_URL="https://fable-api-cbo8.onrender.com/api/v1"`.
3. **Build, Sign & Install to the iPhone:**
   ```bash
   xcodebuild -project frontend/FableApp.xcodeproj -scheme FableApp \
     -destination 'id=<DEVICE_UDID>' \
     DEVELOPMENT_TEAM=<YOUR_TEAM_ID> \
     FABLE_API_BASE_URL="https://<id>.app.lhr.life/api/v1" \
     -allowProvisioningUpdates build

   xcrun devicectl device install app --device <DEVICE_IDENTIFIER> \
     ~/Library/Developer/Xcode/DerivedData/FableApp-*/Build/Products/Debug-iphoneos/FableApp.app
   ```
   *(If macOS prompts for the Keychain password during `codesign`, enter the current Mac login password and click **Always Allow**).*
4. **Trust the Developer Certificate on Your iPhone (One-Time for Personal Teams):**
   - On your iPhone, open **Settings ➔ General ➔ VPN & Device Management**, tap your **Developer App** profile, and tap **Trust**.
   - If campus Wi-Fi blocks Apple's certificate verification server (`ppq.apple.com`) and shows *"An internet connection is required"*, temporarily switch your iPhone to **Mobile Data** for 5 seconds, tap **Trust**, and then re-enable Wi-Fi.
5. **Unplug & Use Wirelessly (Including from a Fedora Linux Laptop):**
   - Once installed, you can change the backend server URL at any time **directly inside the iPhone app** without Xcode:
     - On the **Welcome Screen** (before signing in), tap **"Server: … • Change"** at the bottom.
     - Or inside the app, open **Shelf ➔ Settings ➔ Backend Server URL**.
   - **Using Your Fedora Linux Laptop (or Mac) as the Wireless Backend in One Command:**
     1. Run the unified launcher script from the repository root:
        ```bash
        ./scripts/start_wireless_server.sh
        ```
        *(Creates `.venv` if missing, starts FastAPI on `0.0.0.0:8001` with `FABLE_ENV=development`, and prints both your **Home Wi-Fi / Hotspot URL** `http://<lan-ip>:8001/api/v1` and a **Public HTTPS Tunnel URL** `https://<id>.trycloudflare.com/api/v1`.)*
     2. On Fedora, if using Home Wi-Fi / Hotspot directly, open port `8001` once: `sudo firewall-cmd --add-port=8001/tcp`.
     3. On your iPhone, tap **Server: … • Change** (or **Settings ➔ Backend Server URL**), paste either URL, and tap **Save**.
   - **Re-signing / Refreshing the iOS App from Fedora Linux (7-Day Personal Team Expiry):**
     - Free Apple ID ("Personal Team") provisioning profiles expire after 7 days. Without a physical Mac, build the `.ipa` on GitHub Actions (`macos-latest` runner) and sideload/refresh it on Fedora using **SideStore** or **`altserver-linux`** (`sudo dnf install usbmuxd libimobiledevice`).

---

## 3. Final Capstone Grading & Demonstration Runbook ("The Hero Path")

When demonstrating the application to your professor or grading committee in the lab, follow this sequence and report any live-service limitations accurately:

| Step | Action on Simulator | What It Proves to the Grader |
|---|---|---|
| **1. Cold Launch & Auth** | App opens to `WelcomeView`; register a test account using an address reserved for testing. | Exercises account-scoped authentication and secure device token storage. Passwords use versioned PBKDF2-HMAC-SHA256 hashes; successful logins upgrade legacy hashes. |
| **2. Pure Zero-Baseline State** | Switch to **"Shelf"** tab immediately upon registration. | Proves zero ghost data: authentic empty states render with 0 saved, 0 finished, and 0 reading streak days. |
| **3. Live Library Feed** | Switch to **"Library"** and inspect the available catalog and cover images. | Demonstrates live metadata and official cover URLs from the configured Gutenberg provider. |
| **4. Category Filter Pills** | Tap **"Fables"**, **"Classics"**, **"Mystery"**, **"Fiction"**, then **"All"**. | Demonstrates reactive category filtering across open-source books, Aesop's Fables, folklore, mystery, and classic literature (`StoryStore.isMangaEnabled = false`). |
| **5. Multi-Chapter Book Reader & TOC** | Open a readable classic book (e.g., *Pride and Prejudice*) and tap the **Table of Contents (list)** icon. | Proves the app fetches official Gutenberg plain text on demand and displays its chapters in the in-app reader. |
| **6. Reader Typography & Themes** | Tap the **Display Options (`Aa`)** button in the reader toolbar and toggle between **Parchment**, **Sepia**, **Midnight**, and **OLED** themes and **Serif / Sans / Mono** fonts. | Demonstrates adaptive editorial typography (`ReaderFont`, `ReaderTheme`, `ReaderLineSpacing`) and pacing estimation. |
| **7. Cached Reading** | Open a previously cached book while offline. | Demonstrates offline reading for content already downloaded by the reader. |
| **8. Auditory Narration & Voice Picker** | Tap the **Audio Play** button in Reader toolbar; tap **Voice Selector**. | Activates `AVSpeechSynthesizer` narration state machine. Displays `VoiceSelectionSheet` with live voice audition across regional accents (`en-US`, `en-GB`, `en-AU`). |
| **9. Community Publishing** | Tap **"Write"** tab; author a title and manuscript; tap **"Publish"**. | Validates manuscript, calculates word count, prepends to store catalog, and displays interactive `StoryPublishedSheet`. |
| **10. Sign-Out & Isolation** | Tap **"Profile"** ➔ **Settings** icon ➔ **"Sign Out"**. | Purges reactive session, resets root view state, and returns to authentication screen without data leakage. |

> [!TIP]
> **Pre-Captured Visual Archive:** All **29 full-screen iOS Simulator screenshots** covering every screen, filter pill, modal, and theme—plus a continuous walkthrough video (`fable_ios_full_walkthrough.mp4`)—are already archived and indexed in **[`docs/simulator_captures/README.md`](./simulator_captures/README.md)**.

---

## 4. Capturing High-Res Screenshots for the Final Capstone Report

The final capstone report requires clear, uncompressed retina screenshots of the completed SwiftUI application:

1. In the iOS Simulator window, navigate to each target screen:
   - **Screen 1:** `WelcomeView` / `SignInView` (Modern sans-serif auth branding)
   - **Screen 2:** `LibraryView` (live provider catalog or its empty state)
   - **Screen 3:** `MangaReaderView` (only when the configured live catalog provides readable manga pages)
   - **Screen 4:** `ReaderView` with `VoiceSelectionSheet` (AVSpeech voice selection modal)
   - **Screen 5:** `ReaderView` with `DisplayOptionsSheet` (Font & Theme customization modal)
   - **Screen 6:** `WriteView` (Manuscript draft with live reactive word counter)
   - **Screen 7:** `StoryPublishedSheet` (Story celebration modal with return CTA)
   - **Screen 8:** `ShelfView` (Living reading analytics and zero-baseline shelf)
2. Press **`Cmd + S`** in the Simulator for each screen.
   - *Result:* The Simulator automatically saves a pixel-perfect Retina PNG directly to the Mac's `~/Desktop`.
3. Drag these PNGs into your submission document (e.g. Apple Pages, Microsoft Word, or LaTeX) to export your final Capstone PDF.

---

## 5. Troubleshooting & Recovery on Lab Macs

### Production Release Readiness Gate

Complete these checks against the actual release environment before publishing a production build:

1. Configure the iOS Release build with the production HTTPS API URL. Build and install it on a physical iPhone; verify sign-in, live catalog refresh, remote covers, readable provider chapters, and shelf synchronization. Provider-only chapters that do not expose readable text must open their official source in the in-app browser.
2. Configure the Compose backup destination as durable off-host storage with restricted access. Load `FABLE_BACKUP_ENCRYPTION_KEY_B64` from a secret manager; the backup utility now writes authenticated, encrypted SQLite snapshots. Migrate any existing plaintext snapshots with the `encrypt` command, then verify the encrypted copy before removing the plaintext original. Keep the key separate from the backup destination and retain it for the full backup lifetime. Encryption at rest on the destination remains recommended as a separate layer.
3. Verify a recent encrypted snapshot, restore it into an isolated database with the matching key, and verify representative accounts, stories, chapters, and shelf state before treating backups as recoverable.
4. Configure availability, server-error, backup-freshness, and SMTP-delivery monitoring in the selected hosting/monitoring platform. Assign an operator to receive and act on alerts; the repository does not select a monitoring vendor or configure hosted alerts.
5. Confirm the tagged release workflow has passed backend, Docker/Compose, iOS simulator, and Release build checks. The workflow publishes an image; deployment and the physical-device checks above remain operator tasks.

### Problem 1: Xcode says "No such module" or Package Dependencies Failed
- **Fix:** In Xcode menu, choose **File ➔ Packages ➔ Reset Package Caches**, then **File ➔ Packages ➔ Resolve Package Versions**.

### Problem 2: Stale DerivedData Causing Build Failures
- **Fix:** In Terminal, run:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData/FableApp-*
  ```
  Then re-open Xcode and press `Cmd + B`.

### Problem 3: Simulator Hangs or Fails to Boot
- **Fix:** In Terminal, restart the simulator service:
  ```bash
  killall "Simulator" 2>/dev/null
  xcrun simctl erase all
  ```
  Then press `Cmd + R` in Xcode.

### Problem 4: Git Push/Pull Asking for Username/Password on Shared Mac
- **Fix:** To cache credentials for your lab session without saving permanently:
  ```bash
  git config --global credential.helper 'cache --timeout=7200'
  ```
  *(Credentials will expire automatically after 2 hours).*

---

## 6. End-of-Lab Session Cleanup (Security Best Practice)

Before logging off the shared Mac lab machine:
```bash
# Delete the local repository clone from Desktop
rm -rf ~/Desktop/Fable-IOS

# Clear any cached git credentials
git config --global --unset credential.helper
```
*(Your work remains securely backed up on GitHub at https://github.com/ur1el0/Fable-IOS).*

