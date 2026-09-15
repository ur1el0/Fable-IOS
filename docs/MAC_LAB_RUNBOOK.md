# FABLE: Mac Lab Environment Runbook & Reproducibility Guide

**Target Environment:** Academic Mac Lab Computers (macOS Sonoma / Sequoia, Xcode 15/16)  
**Target Hardware:** Apple Silicon / Intel iMacs or Mac Minis in School Labs  
**Target Objective:** 100% Consistent, Error-Free Clone, Build, Run, and Demo on Any Shared Lab Machine

---

## 1. Golden Rules for Shared Mac Lab Machines

Shared campus computers have unique quirks: shared user profiles, stale build caches from other students, restricted network access, and permission resets on reboot. Follow these principles to avoid common traps:

1. **Clone to a Local User Directory:** Always clone into `~/Desktop` or `~/Documents` (avoid network-mounted shared drives which cause Xcode file-lock errors).
2. **Never Save GitHub Credentials in Lab Keychain:** Avoid `git config --global credential.helper store`. Use temporary in-memory credential caching instead.
3. **Always Verify Destination is an iOS Simulator:** Xcode on lab machines often defaults to *"My Mac (Mac Catalyst)"*, which will fail to compile iOS-only SwiftUI components. Always switch to **iPhone 16 Pro** or **iPhone 15 Pro**.
4. **Zero-Network Grading Guarantee:** Fable does not require Wi-Fi during presentation. If the school Wi-Fi drops or requires a captive portal login, Fable’s in-memory mock store runs with 100% fidelity offline.

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
open frontend.swiftpm
```
*Alternatively:* Open **Xcode** ➔ **File** ➔ **Open...** ➔ Select `frontend.swiftpm`.

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

## 3. Grading & Demonstration Runbook ("The Hero Path")

When demonstrating the application to your professor or teaching assistant in the lab, follow this sequence to showcase **>50% working implementation**:

| Step | Action on Simulator | What It Proves to the Grader |
|---|---|---|
| **1. Cold Launch** | App opens to `LibraryView` | Proves UI compiles cleanly, loads warm parchment theme, and renders seed data. |
| **2. Category Filter** | Tap the **"Folklore"** pill chip | Proves reactive state filtering; feed instantly updates to folklore stories. |
| **3. Hero Story Read** | Tap the **"The Clockmaker of Prague"** Hero Card | Proves modal navigation into `ReaderView`, displaying author metadata and chapter filigree. |
| **4. Typography Engine** | Tap the **"Display Options"** button (bottom right) | Opens `DisplayOptionsSheet`. Switching fonts (*SF Mono*) and themes (*Sepia*) updates text in real-time. |
| **5. Reading Progress** | Scroll down through the story manuscript | Demonstrates dynamic scroll progress tracking and completion threshold logic. |
| **6. Bookmark Toggle** | Tap the **Heart / Bookmark** icon | Proves mutable state updates across views; bookmark status persists. |
| **7. Story Composer** | Tap the **"Write"** tab in the bottom bar | Opens `WriteView`. Enter Title, select Genre, type a synopsis and body text. |
| **8. Dynamic Counter** | Observe the live word counter and read time estimate | Proves mathematical logic (200 WPM) updating reactively as you type. |
| **9. Publish Story** | Tap the **"Publish"** CTA button | Proves input validation, prepends story to collection, and displays `StoryPublishedSheet`. |
| **10. Reading Journal** | Tap the **"Shelf"** tab | Shows newly added story under "Bookmarked", renders 60% and 100% circular progress rings, and displays October reading metrics. |

---

## 4. Capturing High-Res Screenshots for the PDF Report

The midterm instructions require clear screenshots showing the actual SwiftUI application:

1. In the iOS Simulator window, navigate to each target screen:
   - **Screen 1:** `LibraryView` (Filter set to "All")
   - **Screen 2:** `LibraryView` (Filter set to "Folklore" showing Hero card)
   - **Screen 3:** `ReaderView` (Reading manuscript on parchment)
   - **Screen 4:** `DisplayOptionsSheet` (Font & Theme customization modal)
   - **Screen 5:** `WriteView` (Draft with word count active)
   - **Screen 6:** `StoryPublishedSheet` (Publish celebration modal)
   - **Screen 7:** `ShelfView` (Progress rings and October Reading Stats)
2. Press **`Cmd + S`** in the Simulator for each screen.
   - *Result:* The Simulator automatically saves a pixel-perfect Retina PNG directly to the Mac's `~/Desktop`.
3. Drag these PNGs into your submission document (e.g. Apple Pages, Microsoft Word, or Google Docs) to export your final single PDF.

---

## 5. Troubleshooting & Recovery on Lab Macs

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

