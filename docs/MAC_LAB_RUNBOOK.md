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
- The Simulator will launch, boot, and display Fable’s Library feed populated with full seed stories, images, and category chips.

---

## 3. Final Capstone Grading & Demonstration Runbook ("The Hero Path")

When demonstrating the application to your professor or grading committee in the lab, follow this sequence and report any live-service limitations accurately:

| Step | Action on Simulator | What It Proves to the Grader |
|---|---|---|
| **1. Cold Launch & Auth** | App opens to `WelcomeView`; register a test account (`evaluator@university.edu`). | Exercises account-scoped authentication and secure device token storage. Passwords use versioned PBKDF2-HMAC-SHA256 hashes; successful logins upgrade legacy hashes. |
| **2. Pure Zero-Baseline State** | Switch to **"Shelf"** tab immediately upon registration. | Proves zero ghost data: authentic empty states render with 0 saved, 0 finished, and 0 reading streak days. |
| **3. Multi-Format Library Feed** | Switch to **"Library"** tab. Observe mix of prose novels and graphic manga. | Demonstrates multi-format ingestion architecture (`ContentFormat`: `PROSE`, `MANGA`; `SourceProvider`: `GUTENBERG`, `STANDARD_EBOOKS`, `MANGADEX`). |
| **4. Format Filter Pills** | Tap the **"Manga"** chip, then **"Novels"**, then **"All"**. | Proves reactive format filtering and clean sans-serif UI tag architecture. |
| **5. Graphic Manga Reader** | Tap **"Chainsaw Devil: Special Edition"**. | Opens cinema black `MangaReaderView` with vertical continuous Webtoon scrolling and high-resolution sequential panel art. |
| **6. Manga Reading Mode Switch** | Tap the mode toggle in top-right chrome to switch to **"Paging"**. | Demonstrates dual reading engine: transitions effortlessly from vertical continuous scroll to horizontal swipe paging. |
| **7. Prose Reader & Typography** | Return to Library and open **"Dracula"** or **"The Legend of Sleepy Hollow"**. | Demonstrates adaptive typography engine (`ReaderFont`, `ReaderTheme`, `ReaderLineSpacing`) and pacing estimation. |
| **8. Auditory Narration & Voice Picker** | Tap the **Audio Play** button in Reader toolbar; tap **Voice Selector**. | Activates `AVSpeechSynthesizer` narration state machine. Displays `VoiceSelectionSheet` with live voice audition across regional accents (`en-US`, `en-GB`, `en-AU`). |
| **9. Community Publishing** | Tap **"Write"** tab; author a title and manuscript; tap **"Publish"**. | Validates manuscript, calculates word count, prepends to store catalog, and displays interactive `StoryPublishedSheet`. |
| **10. Sign-Out & Isolation** | Tap **"Profile"** ➔ **Settings** icon ➔ **"Sign Out"**. | Purges reactive session, resets root view state, and returns to authentication screen without data leakage. |

---

## 4. Capturing High-Res Screenshots for the Final Capstone Report

The final capstone report requires clear, uncompressed retina screenshots of the completed SwiftUI application:

1. In the iOS Simulator window, navigate to each target screen:
   - **Screen 1:** `WelcomeView` / `SignInView` (Modern sans-serif auth branding)
   - **Screen 2:** `LibraryView` (Multi-format catalog showing both Novels and Manga)
   - **Screen 3:** `MangaReaderView` (High-contrast cinema black manga reader in Webtoon mode)
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
2. Configure the Compose backup destination as durable off-host storage with encryption at rest and restricted access. The backup script creates SQLite snapshots but does not encrypt them itself.
3. Restore a recent snapshot into an isolated database, run the SQLite integrity check, and verify representative accounts, stories, chapters, and shelf state before treating backups as recoverable.
4. Enable GitHub Dependabot security alerts in the repository's **Settings → Code security and analysis**. `.github/dependabot.yml` also requests weekly dependency and GitHub Actions version updates; version update PRs do not enable security alerts.
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

