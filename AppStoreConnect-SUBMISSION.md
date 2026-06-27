# MouseMe — App Store Connect Submission Guide

Use this document when submitting **MouseMe** to App Store Connect. Copy each section into the matching field. Update placeholders marked `[BRACKETS]` before submitting.

---

## Quick facts

| Field | Value |
|--------|--------|
| **App name** | MouseMe |
| **Bundle ID** | `Fermoselle.MouseMe` |
| **SKU** | `mouseme-001` (or your choice — must be unique in your account) |
| **Primary language** | English (U.S.) |
| **Version** | 1.0 |
| **Build number** | 1 |
| **Platforms** | iPhone, iPad, Mac, Apple Vision (universal target) |
| **Category (primary)** | Utilities |
| **Category (secondary)** | Productivity |
| **Price** | Free |
| **In‑App Purchases** | None |
| **Sign in required** | No |
| **Account creation** | No |

---

## 1. App Store listing copy

### App name (30 characters max)
```
MouseMe
```

### Subtitle (30 characters max)
```
Phone remote for your Mac
```

### Promotional text (170 characters — can update without new build)
```
Turn your iPhone into a trackpad, keyboard, and TV remote for your Mac. Same Wi‑Fi, no cloud — your phone controls the cursor on your computer in seconds.
```

### Description (4000 characters max)

```
MouseMe turns your iPhone or iPad into a wireless trackpad, keyboard, media remote, and TV controller for your Mac — all over your local Wi‑Fi. No subscriptions, no cloud account, and no data sent to our servers.

HOW IT WORKS
1. Install and open MouseMe on your Mac (included in the same app — choose “My Mac” in Xcode, or download from the Mac App Store).
2. Enable Receiving on the Mac and grant Accessibility permission when prompted.
3. Open MouseMe on your iPhone, go to Connect, and tap your Mac under “Computers nearby.”
4. Use the Mouse tab to control the cursor, type from the Keyboard tab, and more.

MOUSE MODES
• Trackpad — glide to move, tap to click
• Classic — dedicated left / right / middle buttons and scroll
• Air Mouse — aim with the phone gyroscope
• Desk Slide — lay the phone face-up on your desk and slide it like a mouse
• Gaming — high-DPI touch pad with extra buttons
• Presenter — next/previous slide and laser-style pointing

KEYBOARD & MEDIA
• Full keyboard with modifiers sent to your Mac
• Media keys for volume, brightness, and playback

TV REMOTE
• Control a Roku TV on your network through your Mac
• Multiple remote layouts including Apple TV style
• Tap “Find TVs” to discover Rokus on your Wi‑Fi automatically

CONNECTION OPTIONS
• Automatic discovery (Bonjour) on the same Wi‑Fi
• Manual IP entry and QR code pairing
• Optional Bluetooth mode
• Optional “host on phone” mode for difficult networks

PRIVACY
All control data stays on your local network between your phone and your computer. MouseMe does not collect, store, or transmit your inputs to external servers.

REQUIREMENTS
• iPhone or iPad with iOS/iPadOS 26.2 or later
• A Mac running macOS 26.2 or later with the MouseMe receiver on the same local network
• Local Network permission on iPhone (for discovery)
• Accessibility permission on Mac (to move the cursor and type)

MouseMe is built for people who want their phone to work like a portable mouse and keyboard for the Mac they already own — at their desk, on the couch, or in a presentation.
```

Deployment targets in Xcode: **iOS 26.2**, **macOS 26.2**. If you lower these before release, update this description to match.

### Keywords (100 characters max, comma-separated, no spaces after commas)
```
trackpad,remote mouse,keyboard,mac,wifi,roku,tv remote,presenter,air mouse,controller
```

### Support URL
```
[YOUR SUPPORT URL — e.g. https://github.com/YOURUSER/MouseMe/issues or a simple contact page]
```

### Marketing URL (optional)
```
[YOUR WEBSITE OR GITHUB REPO URL]
```

### Copyright
```
© 2026 [YOUR LEGAL NAME OR COMPANY NAME]
```

---

## 2. App Review Information

Paste into **App Store Connect → App → App Review Information**.

### Contact information
| Field | Value |
|--------|--------|
| First name | [Your first name] |
| Last name | [Your last name] |
| Phone | [Your phone — Apple may call] |
| Email | [Your email — Apple may email] |

### Notes for reviewer (4000 characters max)

```
MouseMe is a UNIVERSAL app. The iPhone/iPad build is the CONTROLLER; the Mac build is the RECEIVER that moves the cursor and injects keyboard events. Both are required to test full functionality.

REVIEW SETUP (recommended — ~5 minutes)

Hardware:
• 1 Mac running macOS 26.2 or later
• 1 iPhone or iPad on the SAME Wi‑Fi network (not guest/isolated Wi‑Fi)

Steps:
1. On the Mac: Launch MouseMe. The Mac window shows “Receiver running on this Mac.” Leave “Receiving” ON.
2. On the Mac: When prompted, grant Accessibility in System Settings → Privacy & Security → Accessibility → enable MouseMe. This is required to move the cursor (standard for remote-control utilities).
3. On the iPhone: Launch MouseMe → Connect tab.
4. On the iPhone: When prompted, tap Allow for LOCAL NETWORK access (required for Bonjour discovery).
5. On the iPhone: Under “Computers nearby,” tap the Mac entry (named “MouseMe [Mac name]”).
6. On the iPhone: Open the Mouse tab → Trackpad style → drag on the touch surface. The Mac cursor should move. Tap to click.

PERMISSIONS USED (and why)

• Local Network — discover the Mac receiver via Bonjour (_mouseme._tcp) on the LAN.
• Camera — optional QR scan on the Connect tab to pair with a computer (Connect → scan QR from Mac helper).
• Motion & Fitness (Core Motion) — Air Mouse, Desk Slide, and Presenter modes translate phone movement into cursor movement.
• Bluetooth — optional BLE transport when Wi‑Fi is unavailable (Connect → More ways → Bluetooth).

FEATURES THAT DO NOT REQUIRE OUR SERVERS
• No login, no account, no analytics SDK, no third-party backend.
• TCP/Bluetooth control events go directly phone → Mac on the local network.

TV REMOTE (optional to test)
• Requires a Roku TV on the same network. iPhone TV tab → Find TVs → select TV → sends IP to Mac receiver → D-pad buttons send Roku commands from the Mac.
• If no Roku is available, skip this — core mouse/keyboard functionality is independent.

MAC-ONLY BUILD
If reviewing the macOS build alone: it runs as a menu-bar-style receiver window waiting for a phone connection. It does not control the cursor until a phone connects and sends events.

QUESTIONS
Contact [YOUR EMAIL]. Happy to provide a screen recording or jump on a brief call.
```

### Sign-in required
**No**

### Demo account
**Not applicable** — no user accounts.

---

## 3. App Privacy (Privacy Nutrition Label)

Answer in **App Store Connect → App Privacy**. MouseMe collects **no data linked to the user** for tracking or analytics based on the current codebase.

### Recommended answers

| Question | Answer |
|----------|--------|
| Do you or your third-party partners collect data from this app? | **No** (if you add no analytics before ship) |
| Data used to track you | None |
| Data linked to you | None |
| Data not linked to you | None |

If you later add crash reporting (e.g. Xcode Organizer only) or analytics, update this section before release.

### Privacy Policy URL
**Required** if you declare any data collection; **strongly recommended** even for “no collection” apps.

Host a simple page with the Privacy Policy text in Section 8 below at your Support URL or a dedicated `/privacy` page.

---

## 4. Age Rating (questionnaire)

Typical answers for MouseMe:

| Content | Rating |
|---------|--------|
| Cartoon / fantasy violence | None |
| Realistic violence | None |
| Sexual content | None |
| Profanity | None |
| Horror | None |
| Mature / suggestive themes | None |
| Gambling | None |
| Unrestricted web access | No |
| User-generated content | No |
| Messaging / chat | No |

**Expected result:** 4+

---

## 5. Export compliance

When uploading the build, Xcode / App Store Connect asks:

| Question | Answer |
|----------|--------|
| Is your app designed to use cryptography or does it contain cryptography? | **Yes** (HTTPS/TLS is standard on iOS; local TCP is not export-controlled in practice) |
| Is the app exempt? | Typically **Yes** — uses only standard OS encryption (HTTPS, standard networking) and qualifies for exemption under category (b) |

If unsure at upload time, choose the exempt path for apps that only use Apple’s built-in encryption for standard networking. Consult Apple’s export compliance docs or legal counsel for commercial distribution.

---

## 6. macOS-specific submission notes

The same binary includes a **Mac receiver**. In App Store Connect:

1. Enable **Mac** under Supported Destinations if not already.
2. Mac screenshots: show the receiver window (Listening on port 8237, Accessibility card if needed).
3. **App Sandbox** is enabled; entitlements include network client + server.
4. Reviewers must grant **Accessibility** on Mac — note this prominently in Review Notes.

### Mac Accessibility justification (for review notes, already included above)
MouseMe injects mouse and keyboard events via macOS Accessibility APIs (`AXIsProcessTrusted`). This is the only Apple-supported way for a receiver app to control the system cursor from network input.

---

## 7. Screenshots checklist

Apple requires screenshots per device class. Capture from Simulator or device.

### iPhone 6.7" (required if supporting iPhone)
1. **Connect** — Mac listed under “Computers nearby”
2. **Mouse / Trackpad** — touch surface with “Connected” status
3. **Keyboard** tab
4. **TV Remote** — layout picker + Find TVs
5. (Optional) Settings — sensitivity / mouse styles

### iPad 12.9" (if supporting iPad)
Same scenes on iPad layout.

### Mac (if Mac App Store enabled)
1. Receiver window — “Listening on port 8237”
2. Connected phone listed in sidebar/card

### Apple Vision Pro (if shipping visionOS)
Mouse tab or Connect screen — only if you intend to support visionOS publicly.

**Tip:** Use status bar clean screenshots; show “Connected to [Mac name]” for clarity.

---

## 8. Privacy Policy (host this on your website)

```
Privacy Policy for MouseMe
Last updated: [DATE]

MouseMe (“the app”) is developed by [YOUR NAME OR COMPANY].

Summary
MouseMe does not sell your data. The app operates primarily on your local network between your phone and your computer. We do not operate a cloud service that receives your mouse movements, keystrokes, or TV commands.

Information the app uses on your device
• Local network: The app discovers and connects to a computer on your Wi‑Fi using Bonjour and local TCP. Connection data (IP address, port) may be stored on your device for reconnect convenience.
• Camera: Used only if you choose to scan a pairing QR code on the Connect screen. Images are processed on-device and are not uploaded.
• Motion sensors: Used for Air Mouse, Desk Slide, and similar modes. Motion data is processed on-device to compute pointer movement and is sent only to your paired computer on your local network.
• Bluetooth: Used only if you enable Bluetooth pairing. Events are sent directly to the paired device.

Information we collect on our servers
We do not operate servers that receive your control input. [If you add crash analytics later, describe it here.]

Children
MouseMe is not directed at children under 13. We do not knowingly collect personal information from children.

Changes
We may update this policy. Continued use of the app after changes constitutes acceptance.

Contact
[YOUR EMAIL]
```

---

## 9. Info.plist permission strings (already in project)

Verify these match App Store Connect / device prompts:

| Key | User-facing string |
|-----|-------------------|
| `NSLocalNetworkUsageDescription` | MouseMe needs local network access to discover and connect to the helper running on your computer. |
| `NSBonjourServices` | `_mouseme._tcp`, `_mousemehost._tcp` |
| `NSCameraUsageDescription` | MouseMe uses the camera to scan a pairing QR code shown by the desktop helper. |
| `NSMotionUsageDescription` | MouseMe uses motion sensors to translate phone movement into mouse movement. |
| `NSBluetoothAlwaysUsageDescription` | MouseMe uses Bluetooth Low Energy to pair with the desktop helper when Wi‑Fi is not available. |

---

## 10. Pre-submission checklist

### Build & signing
- [ ] Archive **Any iOS Device** + **My Mac** (or separate archives per platform per your workflow)
- [ ] Increment `CURRENT_PROJECT_VERSION` for each upload
- [ ] Validate archive in Xcode (no errors)
- [ ] Upload to App Store Connect
- [ ] Select build on the version page

### App Store Connect metadata
- [ ] App name, subtitle, description, keywords
- [ ] Screenshots for each required size
- [ ] App icon (1024×1024) — from Assets catalog
- [ ] Privacy Policy URL
- [ ] Support URL
- [ ] Age rating questionnaire complete
- [ ] App Privacy questionnaire complete
- [ ] Review notes + contact info filled in

### Legal & content
- [ ] You have rights to the app name “MouseMe” (trademark search recommended)
- [ ] No placeholder text left in UI
- [ ] Test on real iPhone + real Mac on same Wi‑Fi

### Review risk mitigations
- [ ] Local Network permission prompt appears and app handles denial gracefully (Connect tab banner)
- [ ] Mac Accessibility instructions visible in-app (? button on Mouse tab + Mac receiver UI)
- [ ] App does something useful without TV/Roku (core trackpad works without Roku)

---

## 11. Optional: Mac App Store separate listing

If you prefer **two listings** (iPhone app + Mac receiver app) instead of one universal app:

| Listing | Role | Bundle ID suggestion |
|---------|------|----------------------|
| MouseMe | iPhone/iPad controller | `Fermoselle.MouseMe` |
| MouseMe Receiver | Mac-only receiver | `Fermoselle.MouseMe-Mac` |

Current project uses **one universal bundle**. A single listing is simpler for users; keep one app unless you split targets later.

---

## 12. What’s New (Version 1.0)

```
Welcome to MouseMe 1.0!

• Use your iPhone as a trackpad, keyboard, and media remote for your Mac
• Multiple mouse modes: Trackpad, Air Mouse, Desk Slide, Gaming, and Presenter
• Automatic Mac discovery on your Wi‑Fi
• TV remote with Roku discovery and multiple layouts including Apple TV style
• All control stays on your local network — private by design
```

---

*Generated for MouseMe v1.0 — update placeholders before submitting.*
