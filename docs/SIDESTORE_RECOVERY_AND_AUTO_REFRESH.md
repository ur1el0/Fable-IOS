# SideStore Recovery & On-Device Auto-Refresh Guide

This guide covers why **SideStore** can stop opening on iOS (`NSPOSIXErrorDomain error 85`), how to recover when `iloader` / `AltServer` hit Apple's `503 Service Temporarily Unavailable` error on `https://gsa.apple.com/grandslam/GsService2`, and how to automate 7-day refreshes on-device using **LocalDevVPN** and **Apple Shortcuts**.

---

## 1. Why SideStore Stops Opening (`error 85` / Revoked Certificate)

On a free Apple ID ("Personal Team"):
- Provisioning profiles expire every **7 days**.
- Apple limits free accounts to **2 active development certificates** and **3 active sideloaded apps**.
- When `iloader` or `AltServer` installs SideStore, it initially signs SideStore with a cross-signed certificate (`isCrossSigned: true`). If you do not immediately refresh SideStore inside SideStore—or if **Xcode** on a Mac shares the same Apple ID and creates/revokes a certificate—iOS invalidates SideStore's signature and refuses to launch it (`NSPOSIXErrorDomain error 85 (0x55)` / *"No Longer Available"*).

---

## 2. Workaround When `iloader` / `AltServer` Return `503` on Login

If `iloader` (`isideload`) or `AltServer` fails with `HTTP 503 Service Temporarily Unavailable` for `https://gsa.apple.com/grandslam/GsService2`, you can re-sign `SideStore.ipa` (`0.7.0+`) using **Xcode's active Apple session** on macOS and install it via `xcrun devicectl`:

1. **Download `SideStore.ipa`** (`0.7.0+`, which includes On-Device Anisette and the `503` sign-in fix) from [SideStore Releases](https://github.com/SideStore/SideStore/releases) and unpack `Payload/SideStore.app`.
2. **Generate a 7-day provisioning profile in Xcode** for `com.SideStore.SideStore.<TEAM_ID>` with the App Group `group.com.SideStore.SideStore.<TEAM_ID>` (`xcodebuild -allowProvisioningUpdates` against a minimal target using that bundle ID and team).
3. **Prepare `SideStore.app`:**
   - Remove `Payload/SideStore.app/PlugIns` (the widget extension requires a separate profile).
   - Update `Payload/SideStore.app/Info.plist`:
     - `CFBundleIdentifier`: `com.SideStore.SideStore.<TEAM_ID>`
     - `ALTAppGroups:0`: `group.com.SideStore.SideStore.<TEAM_ID>`
     - `ALTDeviceID`: `<DEVICE_UDID>`
   - Copy the generated `.mobileprovision` into `Payload/SideStore.app/embedded.mobileprovision`.
4. **Sign and install over USB:**
   ```bash
   codesign --force --sign "<SIGNING_IDENTITY>" --timestamp=none Payload/SideStore.app/Frameworks/OpenSSL.framework
   codesign --force --sign "<SIGNING_IDENTITY>" --entitlements SideStore.entitlements --generate-entitlement-der --timestamp=none Payload/SideStore.app
   codesign --verify --deep --strict Payload/SideStore.app

   xcrun devicectl device install app --device <COREDEVICE_ID> Payload/SideStore.app
   xcrun devicectl device process launch --device <COREDEVICE_ID> com.SideStore.SideStore.<TEAM_ID>
   ```

*(Ensure `SideStore.entitlements` matches the provisioning profile's `application-identifier`, `com.apple.developer.team-identifier`, `com.apple.security.application-groups`, `keychain-access-groups`, and `get-task-allow`.)*

---

## 3. Post-Install Setup on iPhone

1. **Trust the profile (if prompted):** **Settings -> General -> VPN & Device Management** -> tap your Apple ID -> **Trust**.
2. **Turn on LocalDevVPN:** Open **LocalDevVPN** on your iPhone (not the macOS wrapper) and toggle the VPN **ON**.
3. **Refresh SideStore itself:**
   - Open **SideStore -> My Apps** and tap **Refresh** (`7 days`) **next to SideStore**.
   - This moves SideStore off the cross-signed cert onto its own persistent certificate.
4. **Manage `FableApp` in SideStore:**
   - Copy `FableApp.ipa` to `On My iPhone -> SideStore -> FableApp.ipa` (or run `./scripts/export_sidestore_ipa.sh`).
   - In **SideStore -> My Apps -> `+`**, select `FableApp.ipa` so SideStore manages its 7-day refreshes.
   - *(Note: Direct Xcode installs under `com.roosc.FableApp` are separate from SideStore-managed installs under `mseuf.edu.ph.FableApp.<TEAM_ID>`. Remove duplicates to stay within the 3-app free-account limit.)*

---

## 4. Automating 7-Day Refreshes with Apple Shortcuts

To keep SideStore and `FableApp` signed indefinitely over Wi-Fi without a computer:

1. **Create a reusable Shortcut first** (avoids the iOS 17 *"Automation contains no actions"* bug):
   - Open **Shortcuts** -> **Shortcuts** tab -> **`+`**.
   - Add these actions in order:
     1. **LocalDevVPN** -> **`Enable VPN`**
     2. **`Wait`** -> **`3 seconds`** *(allows the loopback VPN tunnel to initialize)*
     3. **SideStore** -> **`Refresh All Apps`**
     4. *(Optional)* **LocalDevVPN** -> **`Disable VPN`**
   - Name the shortcut **`Refresh SideStore`** and tap **Done**.
   - Run it once manually on Wi-Fi to verify both `SideStore` and `FableApp` refresh cleanly.
2. **Attach it to an Automation:**
   - Go to **Shortcuts -> Automation -> `+` -> New Automation**.
   - Pick **Charger -> Is Connected** (or **Time of Day** daily/weekly).
   - Select **Run Immediately** -> **Next**.
   - Tap your **`Refresh SideStore`** shortcut in the list (instead of *New Blank Automation*).

---

## 5. Keeping It Reliable Long-Term

- **Avoid sharing one free Apple ID between Xcode and SideStore:** Using a dedicated secondary free Apple ID only for SideStore prevents Xcode builds from hitting the 2-certificate limit and revoking SideStore's cert.
- **Don't revoke certificates casually:** Revoking an active development cert during sign-in immediately breaks any app on the phone signed with that cert (`error 85`).
- **Paid alternative:** Enrolling in the Apple Developer Program ($99/year) extends provisioning profiles to **1 year** (or **90 days** via TestFlight) and removes the 3-app and 2-certificate limits.
