[English](README.md) | [简体中文](README.zh-CN.md)

# LiteShelf

LiteShelf is a lightweight, native macOS game launcher for organizing and launching games stored on your Mac or external drives.

Your games stay where you put them. Add a folder, browse its icons, and double-click to play.

## Features

- **Native macOS Application** — Swift, SwiftUI and AppKit; Apple Silicon including M1; system light and dark appearance.
- **Lightweight & Fast** — the window opens before background filesystem work; local JSON and PNG caches, no third-party dependencies.
- **External Drive Support** — keep games on a Samsung T7 or another drive; reconnect to restore availability.
- **Custom Folder Scanning** — only folders you explicitly select; no automatic Applications or store-library scanning.
- **Offline First** — no accounts, network requests, telemetry or online artwork.
- **Automatic App Discovery** — recursively find `.app` bundles, read names, versions and bundle identifiers, and use native icons. No traversal inside packages, hidden folders or symbolic links.
- **Persistent Game Library** — disconnected drives keep their game names and icons. Unreadable scans retain previous records.
- **English & Simplified Chinese** — follows macOS language preferences and per-app language settings.
- **Zero Music & Sound Effects** — no audio module, assets or audio preferences.

## Screenshots

Actual macOS 27 application, empty library (English):

![LiteShelf empty library](docs/screenshots/library-en.png)

See [capture notes](docs/screenshots/README.md). No game artwork or fabricated screenshots are included.

## Requirements

- Apple Silicon Mac (M1 or newer), macOS 14 or later, including macOS 27.
- Games must already be complete, runnable macOS `.app` bundles compatible with your Mac.
- Xcode 16 or later to build; Xcode 27 and the macOS 27 SDK are preferred to validate macOS 27.
- No Xcode, Homebrew, network connection or separate runtime is needed to use the packaged app.

## Installation

Download from [Latest stable release](https://github.com/ohxiaoguang/liteshelf/releases/latest), or [All releases and test builds](https://github.com/ohxiaoguang/liteshelf/releases). A release package has not yet been published; source code is available in [ohxiaoguang/liteshelf](https://github.com/ohxiaoguang/liteshelf).

1. Choose `LiteShelf-VERSION-macOS-arm64.dmg`. Files ending in `-unnotarized.dmg` are test builds.
2. Optionally verify the checksum: in the download directory, run `shasum -a 256 -c LiteShelf-VERSION-macOS-arm64.dmg.sha256` (use the actual filename).
3. Open the DMG and drag **LiteShelf.app** to **Applications**. Eject the DMG and open LiteShelf from Applications.

Builds without Developer ID credentials use an ad-hoc signature and have **not** been notarized by Apple. macOS may block them. Only if you trust the source, follow Apple's [official instructions for opening an app from an unidentified developer](https://support.apple.com/102445), including **System Settings → Privacy & Security → Open Anyway** when offered. Never disable Gatekeeper globally. A locally built app is another option.

## Usage

1. Click **Add Game Folder…** and select a directory, for example `/Volumes/T7/Games/`. You can add multiple folders in **Settings**.
2. Put existing `.app` games in that folder or its subfolders. LiteShelf reads metadata and caches icons; it never copies, modifies or unpacks games.
3. Double-click an icon to launch. You can also focus an icon and press Return, or right-click for **Launch**, **Show in Finder**, and **Get Info**.
4. Search by game name. Use **Refresh Library** (`⌘R`) after adding, moving or deleting games. Add a folder with `⇧⌘O`; open Settings with `⌘,`.
5. Remove a folder in Settings to remove only its records and cached icons. Its game files are untouched.

### External drives and permissions

Add the games directory on your external SSD, not the entire drive unless you intentionally want it scanned. LiteShelf stores a read-only security-scoped bookmark and volume identity. It resolves bookmarks without automatically mounting drives or showing permission dialogs.

When a drive disconnects, its cached games become unavailable and remain visible. Mount, unmount and volume-rename notifications trigger a background refresh. On reconnection, bookmarks can follow renamed or relocated volumes, and relative game paths are rebased to the resolved folder. A different disk at the old mount point is rejected by volume identity. If macOS cannot resolve the bookmark or permissions changed, use **Choose Again…** in Settings. Select the same folder, or its new location if you moved it. No other directories are searched to guess its location.

A successful complete refresh removes records for games actually deleted from a connected folder. A failed or partial refresh preserves unavailable records. Overlapping selected folders are deduplicated in the grid; removing one retains records belonging to another selected folder. Hard-link aliases are not treated as the same game, and distinct copies sharing a bundle ID remain separate.

### Language

English is the development and fallback language. LiteShelf follows the ordered macOS language list: the first supported English or Chinese preference wins; every `zh` variant uses Simplified Chinese. If none is supported, it uses English. Region and IP address are never used. To override it for this app, use **System Settings → General → Language & Region → Applications**, select LiteShelf and restart it. There is no in-app language selector. A process-only language normalization before AppKit startup also keeps native menus and dialogs in Simplified Chinese for Chinese variants, without writing to saved language settings.

## Build from source

Open `LiteShelf.xcodeproj` in Xcode, select the **LiteShelf** scheme and **My Mac**, then Run. For command-line builds:

```sh
xcodebuild -project LiteShelf.xcodeproj -scheme LiteShelf \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
codesign --force --sign - build/DerivedData/Build/Products/Release/LiteShelf.app
open build/DerivedData/Build/Products/Release/LiteShelf.app
```

Build, verify and package a standalone ad-hoc-signed ARM64 app:

```sh
./scripts/build-dmg.sh 1.0.0
```

Output: `build/dist/LiteShelf-1.0.0-macOS-arm64-unnotarized.dmg` and `.dmg.sha256`. The DMG includes LiteShelf.app, an Applications symlink, and an unnotarized-build notice. Run from a clean output directory, or set `OUTPUT_DIR` to a new directory; the script refuses to overwrite packages. `DERIVED_DATA` and `BUILD_NUMBER` can also be set. On macOS 27, packaging uses `diskutil image create from`; older hosts use `hdiutil` with an explicit HFS+ filesystem. No generators or package managers are required. The icon PNGs are committed; `scripts/generate-icon.swift` is an optional native icon source.

Run tests:

```sh
xcodebuild -project LiteShelf.xcodeproj -scheme LiteShelf \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/TestData CODE_SIGNING_ALLOWED=NO test
```

The app is deliberately not App Sandbox restricted, so macOS can launch user-selected standalone games. It uses security-scoped bookmarks for explicit folder access and does not request network access or perform unselected scans. The runtime is hardened when Developer ID signed. Gatekeeper remains in control of game launches.

### Data and source layout

Library metadata, read-only bookmarks and 128×128 PNG icons live in `~/Library/Application Support/LiteShelf/`. No game content is stored there. The library is written atomically; unused icons are pruned after a successful save. A corrupt or unsupported JSON cache is preserved and reported rather than silently overwritten. Quit the app and restore `Library.json` from a backup, or move it aside to rebuild a fresh library.

`LiteShelf/Models` contains the data model and localization helper; `Services` handles background scans, persistence, launch and volume events; `Views` contains the grid, settings and game information; `Resources` contains the String Catalog and native icon assets. `LiteShelfTests` exercises filesystem boundaries, caches, offline retention, search, deduplication and language selection.

## GitHub Actions and releases

[CI](.github/workflows/ci.yml) builds, tests and smoke-tests DMG packaging on pushes and pull requests. [Release](.github/workflows/release.yml) tests before building and publishing. The default runner is GitHub's [documented ARM64 `xcode-27` image](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/). Set repository variable `MACOS_RUNNER` to another available GitHub-hosted macOS label if necessary. The scripts use the installed default Xcode, report the SDK, fail below SDK 14, and warn below SDK 27 rather than pretending to validate that SDK.

After publishing this source to **your own repository**, review the code and update the changelog, then:

```sh
git tag v1.0.0
git push origin v1.0.0
```

Only `vMAJOR.MINOR.PATCH` tags pass validation. The tag supplies `MARKETING_VERSION`, and the built Info.plist must match. The workflow creates the ARM64 DMG and SHA-256 file, uploads artifacts, then creates a new GitHub Release with generated notes. It refuses to overwrite an existing release. Asset uploads are completed in a draft before publication. Build, notarization or asset upload failure prevents publication. Only the publishing job receives `contents: write`; checkout credentials are not persisted. Manual **Run workflow** builds artifacts only, even when run against a tag.

With no signing secrets, releases are explicitly marked **Unnotarized Test Build**, are GitHub **prereleases**, and do not replace Latest stable. Find them under All releases. With complete valid credentials, packages are signed, notarized and stapled before a stable release is published. Names are `LiteShelf-VERSION-macOS-arm64.dmg` and `.dmg.sha256` for notarized packages, with `-unnotarized` added for test packages.

### Optional signing and Apple notarization

Configure **all six** repository Actions secrets, or none:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded Developer ID Application certificate **with private key**, exported as `.p12` |
| `DEVELOPER_ID_P12_PASSWORD` | Password protecting that `.p12` |
| `DEVELOPER_ID_IDENTITY` | Exact identity, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Apple developer account email |
| `APPLE_APP_PASSWORD` | Apple app-specific password for notarization |
| `APPLE_TEAM_ID` | Apple Developer team ID |

The script creates a temporary keychain, signs with hardened runtime, submits the app ZIP, staples the app, creates and signs the DMG, notarizes/staples the DMG, and verifies it. The keychain and private material are removed on exit. Partial configuration or a failed Apple submission fails the build; it never silently falls back to an unnotarized stable release. The same variables can be securely supplied locally. Never commit certificates, private keys, credentials or personal games.

## FAQ

**Does LiteShelf install or fix games?** No. Games must already work on your Mac. Windows `.exe`, `.ipa`, `.dmg`, store integrations, downloads and game-resource management are outside scope.

**Can I keep several games with the same bundle identifier?** Yes. Entries use their folder and relative path; distinct game copies remain distinct.

**Why is a game unavailable?** Reconnect its drive, refresh, and if necessary choose its folder again in Settings. A renamed or deleted game is rediscovered on the next complete scan. Offline entries are retained until the drive returns or you remove its folder.

**Why did macOS block a game?** LiteShelf uses NSWorkspace and respects macOS security. Check compatibility, permissions and Apple's security guidance above. LiteShelf does not remove quarantine or bypass Gatekeeper.

**Does it stay running in the background?** There is no helper, login item or background service. Volume events are observed while the app is running. Quit with `⌘Q`.

**Has everything been tested?** See [VALIDATION.md](docs/VALIDATION.md) for the exact local results and remaining hardware, signing and GitHub-hosted checks. No performance numbers or unrun CI results are claimed.

## License

[MIT License](LICENSE). Game software and resources are not included and retain their respective licenses.
