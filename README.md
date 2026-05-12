# YTGet

A lightweight, native macOS app for downloading video, audio, and transcripts from YouTube and any other site supported by [yt-dlp](https://github.com/yt-dlp/yt-dlp).

![YTGet v1.2](assets/YTGet%20v1.2.png)

## Features

- **Video downloads** — saves as MP4 at your choice of quality (Best, 4K, 1080p, 720p)
- **Audio downloads** — extracts audio as MP3 at your choice of bitrate (Best, 320k, 192k, 128k)
- **Transcript downloads** — saves a clean, readable Markdown file with the video title and source URL; optionally save the raw SRT with timestamps instead
- **Filename conflict detection** — if a file with the same name already exists, choose to use a unique filename, overwrite, or cancel before the download starts
- **Download queue** — add multiple URLs and they'll be processed sequentially, with live progress, speed, and ETA for each item
- **Persistent queue** — the queue survives app restarts; completed items remain visible until you clear them
- **Auto-installs dependencies** — detects yt-dlp and ffmpeg via Homebrew and offers to install them if missing; shows installed versions in the status bar
- **Dependency update notifications** — checks for yt-dlp and ffmpeg updates on launch with options to update, remind tomorrow, or skip a version
- **Auto-updates** — YTGet checks for new versions of itself on launch via [Sparkle](https://sparkle-project.org) and prompts you to update in the background; also available via **YTGet → Check for Updates…**
- **macOS notifications** — notifies you when a download completes; click to open the file in Finder
- **Right-click menu** — copy source URL, copy transcript text, or reveal the downloaded file in Finder from any queue item
- **Paste-and-go** — automatically populates the URL field from your clipboard when focused
- **Configurable** — choose your output folder, filename template, and whether to embed thumbnails and metadata in audio files

## Requirements

- macOS 14 (Sonoma) or later
- [Homebrew](https://brew.sh) — YTGet will offer to install yt-dlp and ffmpeg automatically via Homebrew on first launch

## Installation

Download the latest release from the [Releases](https://github.com/leaskc/YTGet/releases) page and drag YTGet into your Applications folder.

> On first launch, macOS may ask you to confirm you want to open the app. Right-click the app and choose Open if prompted.

Once installed, YTGet will notify you automatically when new versions are available.

## Usage

1. Paste a YouTube (or any yt-dlp-compatible) URL into the input field
2. Choose a format: **Video**, **Audio Only**, or **Transcript**
3. Press **Add** or hit Return
4. YTGet resolves the title and thumbnail, then begins downloading

Output is saved to `~/Downloads` by default. Change this in the toolbar or in Settings (⌘,).

## Tech Stack

- Swift / SwiftUI (macOS 14+)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — The Unlicense
- [ffmpeg](https://ffmpeg.org) — LGPL 2.1+
- [Homebrew](https://brew.sh) — BSD 2-Clause
- [Sparkle](https://sparkle-project.org) — MIT

## Building from Source

Open `YTGet.xcodeproj` in Xcode 15 or later and build the YTGet scheme. Requires macOS 14 SDK. Swift Package Manager will resolve the Sparkle dependency automatically on first build.

## Creating a Release DMG

A build script is included to produce a correctly laid-out, Sparkle-signed DMG for distribution.

**Prerequisites**
```bash
brew install create-dmg
```

You will also need the `sign_update` binary from Sparkle placed in the `releases/` folder. It is generated automatically when you build the project in Xcode — copy it from:

```
$(DERIVED_DATA)/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update
```

**Usage**

1. Archive the app in Xcode: **Product → Archive**, then export the `.app` via the Organizer
2. Run the script, passing the path to the exported `.app`:

```bash
cd releases
./build-dmg.sh /path/to/YTGet.app
```

The script will:
- Create `YTGet-{version}.dmg` with the correct DMG window layout
- Sign the DMG with your EdDSA private key (stored in your macOS Keychain)
- Automatically update `appcast.xml` with the new version entry

**Publishing a release**

```bash
# 1. Commit and push appcast.xml — this triggers Sparkle delivery to existing users
git add appcast.xml && git commit -m "Release 1.x.x" && git push

# 2. Create the GitHub release and attach the DMG
gh release create v1.x.x releases/YTGet-1.x.x.dmg --title "YTGet 1.x.x"
```
