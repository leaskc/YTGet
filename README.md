# YTGet

A lightweight, native macOS app for downloading video, audio, and transcripts from YouTube and any other site supported by [yt-dlp](https://github.com/yt-dlp/yt-dlp).

## Features

- **Video downloads** — saves as MP4 at your choice of quality (Best, 4K, 1080p, 720p)
- **Audio downloads** — extracts audio as MP3 at your choice of bitrate (Best, 320k, 192k, 128k)
- **Transcript downloads** — saves a clean, readable Markdown file with the video title and source URL; optionally save the raw SRT with timestamps instead
- **Download queue** — add multiple URLs and they'll be processed sequentially, with live progress, speed, and ETA for each item
- **Persistent queue** — the queue survives app restarts; completed items remain visible until you clear them
- **Auto-installs dependencies** — detects yt-dlp and ffmpeg via Homebrew and offers to install them if missing; shows installed versions in the status bar
- **Update notifications** — checks for yt-dlp and ffmpeg updates on launch with options to update, remind tomorrow, or skip a version
- **macOS notifications** — notifies you when a download completes; click to open the output folder in Finder
- **Right-click menu** — copy the source URL or reveal the downloaded file in Finder from any queue item
- **Paste-and-go** — automatically populates the URL field from your clipboard when focused
- **Configurable** — choose your output folder, filename template, and whether to embed thumbnails and metadata in audio files

## Requirements

- macOS 14 (Sonoma) or later
- [Homebrew](https://brew.sh) — YTGet will offer to install yt-dlp and ffmpeg automatically via Homebrew on first launch

## Installation

Download the latest release from the [Releases](https://github.com/leaskc/YTGet/releases) page and drag YTGet into your Applications folder.

> On first launch, macOS may ask you to confirm you want to open the app. Right-click the app and choose Open if prompted.

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

## Building from Source

Open `YTGet.xcodeproj` in Xcode 15 or later and build the YTGet scheme. Requires macOS 14 SDK.

## Creating a Release DMG

A build script is included to produce a correctly laid-out DMG for distribution.

**Prerequisites**
```bash
brew install create-dmg
```

**Usage**

1. Archive the app in Xcode: **Product → Archive**, then export the `.app` via the Organizer
2. Place the exported `YTGet.app` in the `releases/` folder
3. Run the script from the `releases/` folder:

```bash
cd releases
./build-dmg.sh YTGet.app
```

This produces `YTGet-{version}.dmg` in the same folder, with the app icon and Applications shortcut laid out in a fixed-size window. The version number is read automatically from the app bundle.
