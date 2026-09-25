<p align="center">
<img src="https://raw.githubusercontent.com/mertizci/browser-picker/refs/heads/main/BrowserPicker/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="128" />
</p>

<h1 align="center">Browser Picker</h1>

<p align="center">
A native macOS menu bar app that becomes your <b>default browser</b> and sends every link to the right <b>browser <em>and</em> profile</b> — automatically with rules, or with a quick picker.
</p>

<p align="center">
<img src="https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white" alt="macOS 14.0+" />
<img src="https://img.shields.io/badge/Apple%20Silicon%20%2B%20Intel-Universal-555555" alt="Universal binary" />
<img src="https://img.shields.io/badge/Signed%20%26%20Notarized-Apple-brightgreen" alt="Signed & notarized" />
<a href="https://github.com/mertizci/browser-picker/releases/latest"><img src="https://img.shields.io/github/v/release/mertizci/browser-picker?label=download&color=blue" alt="Latest release" /></a>
<a href="https://www.paypal.com/donate/?hosted_button_id=8BKTHWAHUPWPG"><img src="https://img.shields.io/badge/Donate-PayPal-0070ba?logo=paypal&logoColor=white" alt="Donate via PayPal" /></a>
</p>

---

> **This is a fork.** The original **Browser Picker** was created by **Mert IZCI** ([mertizci/browser-picker](https://github.com/mertizci/browser-picker)) — all credit for the core app goes to him. This fork, maintained by **Fernando Miranda**, adds Opera/Arc support, the ability to add any custom browser, and private/incognito mode routing on top of his original work.
>
> 📦 **[Download this fork's build](https://github.com/fernandom78/browser-picker/releases/download/v1.0.5-fmiranda/BrowserPicker-custom-1.0.5.zip)** — not signed/notarized, so right-click the app → **Open** on first launch instead of double-clicking.

## Why Browser Picker?

Juggling a personal Chrome, a work Chrome profile, and Firefox for clients? Stop opening links in the wrong place. Browser Picker routes each link to the exact **browser and profile** you want — so work links land in your work profile, personal links in your personal one, automatically.

## Install

> A **universal build** that runs natively on both Apple Silicon and Intel Macs (macOS 14.0+). Every release is signed with a Developer ID certificate and **notarized by Apple**, so it opens without Gatekeeper warnings.

### 1. DMG — recommended

> ⚠️ This DMG is the **original, unmodified** Browser Picker from upstream — it does **not** include this fork's Opera/Arc, custom-browser, or private-mode features. For those, use [this fork's build](https://github.com/fernandom78/browser-picker/releases/download/v1.0.5-fmiranda/BrowserPicker-custom-1.0.5.zip) instead.

1. Download `BrowserPicker-X.Y.Z.dmg` from the **[latest release](https://github.com/mertizci/browser-picker/releases/latest)**.
2. Open the DMG and drag **Browser Picker** into your **Applications** folder.
3. Launch it from Applications — the icon appears in your menu bar.

### 2. Homebrew

```bash
brew install --cask mertizci/tap/browser-picker
```

## Features

- 🎯 **Browser + profile routing** — not just "open in Chrome", but "open in Chrome → *Work*" or "Firefox → *Client A*". Each link lands in the right account, ready to go.
- 🧭 **Menu bar control** — pick the active browser + profile (Safari, Chrome, Edge, Brave, Vivaldi, Opera, Arc, Firefox, or any custom browser you've added) in one click.
- ➕ **Add any browser** — beyond the built-in list, point Settings → Browsers → **Add Custom Browser…** at any other Chromium-based browser's `.app` to get the same profile-aware routing, now or as new browsers show up in the future.
- 🕶️ **Private/incognito routing** — send matched links straight to a private/incognito window, still scoped to the right browser and profile. Available per-rule, or as a one-off toggle in the manual picker.
- 🔀 **Automatic routing rules** — match links by *URL contains*, *host equals*, or *host suffix*. First match wins; reorder by dragging. Each rule can also force private/incognito mode.
- 🪃 **Two fallback modes** when no rule matches:
  - **Silent** — open in your current menu bar selection.
  - **Picker** — prompt for the browser/profile (with its own private-mode toggle) each time.
- 👤 **Profile discovery**
  - Chromium browsers (Chrome, Edge, Brave, Vivaldi, Opera, Arc, and custom additions) — from each browser's `Local State`. Custom browsers are matched against a few common Chromium folder conventions automatically, with a manual override if detection misses.
  - Firefox — from `profiles.ini` and Firefox **Profile Groups** (selectable profile names).
  - Safari — from `SafariTabs.db`, with a **menu scan** fallback.
- 🗂️ **Curate your profile list** — in Settings → Browsers, hide profiles you don't use (trash icon) and drag the ☰ handle to reorder a browser's profiles. See [Managing profiles](#managing-profiles).
- 🧑‍🏫 **Guided onboarding** that requests and live-tracks the required permissions.
- ✨ **Polished UI** — window-style menu bar popover, redesigned Settings, rule editor with live preview, built-in **FAQ** and **About**.
- 🖼️ Native browser icons from installed apps, with Simple Icons SVG fallback.

## Permissions

| Permission | Why it's needed |
| --- | --- |
| **Accessibility** | Drive Safari's *File → New … Window* menu to open links in a specific Safari profile. |
| **Full Disk Access** | Read Safari profile names from the protected `SafariTabs.db`. |

On first launch an onboarding window walks you through both. After granting **Accessibility**, **quit and reopen** the app — macOS only applies that permission on a fresh launch.

## Requirements

**To run:**

- macOS 14.0 (Sonoma) or later
- Apple Silicon or Intel — ships as a universal binary

**To build from source:**

- Xcode 15+
- An Apple Development signing certificate (a stable code signature keeps the Accessibility grant across rebuilds)

## Build

```bash
brew install xcodegen   # once
xcodegen generate
xcodebuild -scheme BrowserPicker -destination 'platform=macOS' -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/BrowserPicker-*/Build/Products/Debug/BrowserPicker.app
```

Or open `BrowserPicker.xcodeproj` in Xcode and press ⌘R.

> Signing is configured in `project.yml` (`CODE_SIGN_IDENTITY`). Ad-hoc signatures change on every build and break the Accessibility grant, so a real "Apple Development" identity is recommended.

## Tests

A small XCTest smoke-test suite (`BrowserPickerTests/`) covers the app's core routing/matching/decoding logic — no GUI, no real browsers, runs in under a second.

**Runs automatically in CI** — [`.github/workflows/tests.yml`](.github/workflows/tests.yml) runs the full suite on every push and pull request targeting `main`, on GitHub's own macOS runners, so a regression gets caught before it merges.

To run it yourself after any change:

```bash
xcodegen generate   # only if project.yml changed
xcodebuild test -scheme BrowserPicker -destination 'platform=macOS'
```

Or press ⌘U in Xcode. What's covered:

- **`RuleMatcherTests`** — `urlContains` / `hostEquals` / `hostSuffix` matching, including that a suffix rule for "company.com" doesn't also match an unrelated "evilcompany.com".
- **`RuleEngineTests`** — priority ordering, skipping disabled rules, falling back to the default target, and a matched rule's `openPrivately` flag being surfaced correctly.
- **`CodableCompatibilityTests`** — `BrowserIdentity` stays wire-compatible with old `config.json` files (a built-in browser still encodes as a plain string like `"chrome"`), and `RoutingRule.openPrivately`, `AppSettings.customBrowsers` and `AppSettings.hiddenProfiles` all default correctly when decoding a config saved before those fields existed.
- **`ProfileOrderTests`** — applying a saved profile order (new profiles go at the end), moving a profile up or down, and ignoring drops across different browsers.
- **`BrowserResolutionTests`** — per-browser private-mode flag resolution (this is the regression test for the Edge `--inprivate` vs `--incognito` bug found during development), and `BrowserIdentity.resolved(customBrowsers:)` for both built-in and custom browsers.
- **`ChromiumLocalStateParserTests`** — parsing a real-shaped `Local State` file, including missing/malformed files and profiles with no `name` field.

## Setup

1. Launch Browser Picker — the icon appears in the menu bar.
2. Complete the onboarding (grant Accessibility + Full Disk Access).
3. Choose **Set as Default Browser…** from the menu bar.
4. Pick your default browser and profile.
5. Open **Settings → Rules** to add routing rules (e.g. *URL contains `r2o` → Firefox · Work*).

## Custom browsers

Not every browser ships built in — Settings → Browsers → **Add Custom Browser…** lets you point at any other browser's `.app` (e.g. one not on the built-in Chrome/Edge/Brave/Vivaldi/Opera/Arc list). Custom browsers are treated as Chromium-based, since that covers virtually every browser worth adding beyond the built-in list.

- **Profile discovery** tries a few common Chromium folder conventions under `~/Library/Application Support` automatically. If a custom browser's profiles aren't detected, use **Set Profile Location…** on its card to point directly at its `Local State` file.
- **Private/incognito mode** for a custom browser defaults to the `--incognito` flag, which the large majority of Chromium forks use. A few (Microsoft Edge, built in, is a known example) rename the feature and use a different flag — if a custom addition turns out to do the same, its rules just won't actually go private until that's added as a special case.
- Removing a custom browser also removes any rules pointing at it.

## Managing profiles

Settings → Browsers lists every discovered profile, grouped by browser.

- **Hide a profile** — click the trash icon on its row. It disappears from the picker and menu bar, and stays hidden across relaunches. Clicking **Refresh** (in Settings or the menu bar) brings all hidden profiles back. The profile itself is untouched in the browser.
- **Reorder profiles** — drag the ☰ handle on the left of a row onto another row of the same browser. The picker and menu bar follow the same order, and it survives relaunches and Refresh. Newly discovered profiles are added at the end.

Both are stored in `config.json` (`hiddenProfiles` and `profileOrder`).

## Private / incognito mode

Any routing rule can be set to open in a private/incognito window (still scoped to the rule's chosen browser + profile), and the manual picker has its own independent private-mode toggle for one-off use. One caveat: **Safari's private browsing isn't scoped per-profile** the way Chromium's incognito is, so a private pick in Safari just opens *a* private window rather than one tied to a specific profile.

## Configuration

Settings are stored as JSON at:

```
~/Library/Application Support/BrowserPicker/config.json
```

## Project structure

```
BrowserPicker/
├── BrowserPickerApp.swift           # App entry, AppDelegate, URL handling
├── Core/                            # Models, SettingsStore, RuleEngine, URLRouter
├── Browsers/
│   ├── BrowserLauncher.swift        # Chromium/Firefox/Safari dispatch
│   ├── SafariLauncher.swift         # AppleScript profile targeting
│   ├── AutomationPermissionService  # PermissionMonitor (Accessibility + FDA)
│   └── ProfileDiscovery/            # Per-browser profile discovery
├── UI/                              # Menu bar, Settings, Rules, Onboarding, FAQ, About
└── Resources/                       # faq.html, browser SVG icons
```

## Test

```bash
# After making Browser Picker the default browser:
open "https://example.com"
```

## Troubleshooting

- **Accessibility shows "not granted" after granting** — quit and reopen the app (use *Quit & Reopen*); macOS applies it only on a fresh launch.
- **Accessibility still shows "not granted" even after toggling it off/on and Quit & Reopen** — this usually means stale entries from rebuilding with an ad-hoc signature (each rebuild counts as a "new" app to macOS's permission system). Fix: quit the app, run `tccutil reset Accessibility com.browserpicker.app` in Terminal, relaunch, and grant Accessibility again from a clean slate.
- **Safari profiles missing** — grant Full Disk Access, or open Safari and use *Scan Safari Profiles* in Settings → Browsers.
- **App icon looks blank** — quit/reopen; if it persists, log out and back in to clear the macOS icon cache.

## Contact

Original app developed by **Mert IZCI** — [mertizci@gmail.com](mailto:mertizci@gmail.com).

This fork (Opera/Arc support, custom browsers, private/incognito mode) is maintained by **Fernando Miranda**.

## License

Browser Picker application code is provided as-is. Browser SVG fallbacks use [Simple Icons](https://simpleicons.org/) (MIT). See `BrowserPicker/Resources/Icons/browsers/ATTRIBUTION.md`.
