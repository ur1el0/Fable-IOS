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
- The Simulator will launch and display the Library. Fresh installs do not include seeded stories; the feed depends on the configured backend and provider catalog. Without those services, expect an empty or previously cached library.

---

## 3. Final Capstone Grading & Demonstration Runbook ("The Hero Path")

When demonstrating the application to your professor or grading committee in the lab, follow this sequence and report any live-service limitations accurately:

| Step | Action on Simulator | What It Proves to the Grader |
|---|---|---|
| **1. Cold Launch & Auth** | App opens to `WelcomeView`; register a test account using an address reserved for testing. | Exercises account-scoped authentication and secure device token storage. Passwords use versioned PBKDF2-HMAC-SHA256 hashes; successful logins upgrade legacy hashes. |
| **2. Pure Zero-Baseline State** | Switch to **"Shelf"** tab immediately upon registration. | Proves zero ghost data: authentic empty states render with 0 saved, 0 finished, and 0 reading streak days. |
| **3. Live Library Feed** | Switch to **"Library"** and wait for the configured provider catalog to load. | Demonstrates live provider content and metadata. A fresh install has no bundled catalog; do not expect a particular title or format. |
| **4. Format Filters** | If the live catalog contains both formats, tap **"Manga"**, **"Novels"**, then **"All"**. | Demonstrates reactive format filtering for the formats actually returned by the backend. |
| **5. Manga Reader** | If a manga with readable pages is available, open it from the live catalog. | Demonstrates `MangaReaderView`, vertical Webtoon scrolling, and provider page images. Skip this step when the configured catalog has no readable manga. |
| **6. Manga Reading Mode Switch** | In an available manga, use the mode toggle to switch to **"Paging"**. | Demonstrates continuous scroll and horizontal page navigation. |
| **7. Prose Reader & Typography** | Open a live prose title whose chapter endpoint returns readable text. | Demonstrates adaptive typography (`ReaderFont`, `ReaderTheme`, `ReaderLineSpacing`) and pacing estimation. Provider-only chapters without readable text should open their official source in the in-app browser. |
| **8. Auditory Narration & Voice Picker** | Tap the **Audio Play** button in Reader toolbar; tap **Voice Selector**. | Activates `AVSpeechSynthesizer` narration state machine. Displays `VoiceSelectionSheet` with live voice audition across regional accents (`en-US`, `en-GB`, `en-AU`). |
| **9. Community Publishing** | Tap **"Write"** tab; author a title and manuscript; tap **"Publish"**. | Validates manuscript, calculates word count, prepends to store catalog, and displays interactive `StoryPublishedSheet`. |
| **10. Sign-Out & Isolation** | Tap **"Profile"** ➔ **Settings** icon ➔ **"Sign Out"**. | Purges reactive session, resets root view state, and returns to authentication screen without data leakage. |

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

