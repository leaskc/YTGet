# YTGet - macOS GUI for yt-dlp
## Product Specification v1.1

**Date:** March 2026
**Purpose:** Complete specification for a native macOS GUI wrapping yt-dlp. Intended for use with Claude Code.

---

## Overview

A lightweight, native macOS application that provides a clean GUI for yt-dlp. The user pastes a URL, chooses a basic format preference, and downloads video or audio to a chosen folder. The app manages yt-dlp automatically via Homebrew and shows live download progress. The v1.0 feature set is deliberately minimal; the architecture must be designed to support richer yt-dlp options in later versions.

---

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (macOS 14+ target)
- **Process management:** Foundation `Process` / `AsyncStream` for yt-dlp subprocess calls
- **Persistence:** `UserDefaults` for preferences; no database required in v1.0
- **Distribution:** Direct download (signed and notarised `.dmg`), not Mac App Store (to avoid sandboxing restrictions on subprocess execution)

---

## Dependency Management - yt-dlp

The app must manage yt-dlp automatically. The user should never need to touch the terminal.

### On first launch
1. Check whether `yt-dlp` is available at `/opt/homebrew/bin/yt-dlp` or `/usr/local/bin/yt-dlp`.
2. If not found, check whether Homebrew is installed (`/opt/homebrew/bin/brew` or `/usr/local/bin/brew`).
3. If Homebrew is present, prompt the user: "yt-dlp is not installed. Install it now via Homebrew?" - offer Install and Cancel buttons.
4. If the user accepts, run `brew install yt-dlp` in a visible terminal-style output panel within the app so they can see progress.
5. If Homebrew is not present, show a clear message explaining that Homebrew is required, with a button linking to `https://brew.sh`.
6. If yt-dlp is found, show its version in the status bar (e.g. "yt-dlp 2025.x.x").

### Dependency checking
yt-dlp requires `ffmpeg` to merge separate video and audio streams (essential for best-quality MP4 output). After confirming yt-dlp is present, the app must also check for `ffmpeg`.

- Check for `ffmpeg` at `/opt/homebrew/bin/ffmpeg` or `/usr/local/bin/ffmpeg`.
- If missing, prompt: "ffmpeg is required for video downloads. Install it now via Homebrew?" with Install and Cancel buttons.
- Install via `brew install ffmpeg` in the same visible output panel used for yt-dlp installation.
- If the user cancels, show a persistent warning banner: "ffmpeg not found - video downloads may fail." The user can dismiss this banner, but it will reappear on next launch until ffmpeg is installed.
- Both yt-dlp and ffmpeg versions should be visible in the status bar (e.g. "yt-dlp 2025.x.x - ffmpeg 7.x").

If additional yt-dlp dependencies are identified during development (e.g. `aria2` for accelerated downloads), apply the same check-and-prompt pattern via the same `DependencyChecker` service (see Architecture Notes).

### Ongoing - update checks
- On each launch (after first), silently check for updates to both yt-dlp and ffmpeg in the background.
- If a newer version is available (`brew outdated yt-dlp` / `brew outdated ffmpeg`), show a non-intrusive banner per outdated package: "[package] update available. Update now?"
- Banner actions: **Update now**, **Remind me tomorrow**, **Skip this version**.
  - "Remind me tomorrow" stores a timestamp in `UserDefaults`; the banner will not reappear until the next launch after 24 hours have elapsed.
  - "Skip this version" stores the current available version string in `UserDefaults`; the banner will not reappear until a newer version is detected.
  - "Update now" runs `brew upgrade [package]` in the visible output panel.
- Update checks must not block the UI or delay the app becoming usable.

---

## Application Layout

Single-window app. No sidebar. Clean, minimal layout.

```
+-------------------------------------------------------+
| [App toolbar: output folder picker]  [yt-dlp version] |
+-------------------------------------------------------+
| URL input field                          [Add] button |
+-------------------------------------------------------+
| Format selector: ( Video )  ( Audio only )            |
+-------------------------------------------------------+
|                                                       |
|  Download queue list                                  |
|  - Each item: thumbnail | title | progress bar | ETA  |
|                                  [Cancel] button      |
|                                                       |
+-------------------------------------------------------+
| Status bar: "Ready" / "Downloading 1 of 2..." etc.    |
+-------------------------------------------------------+
```

---

## UI Design

Reference designs were generated using Google Stitch and are stored in the Stitch project **"YTGet - yt-dlp macOS GUI"** (project ID: `12602331157124271007`). Two screens are available:

- **Main window** (screen ID: `d044ccd878f74623b0ea1435ce07af8f`) - download queue, URL input, format selector, toolbar, status bar
- **Settings** (screen ID: `2f03ab029d8f4b8e98c544183d20074a`) - General, Downloads, and About sections

### Design System - "Aqua Graphite"

The generated designs use the following design system. Claude Code should treat these as the visual target.

**Colour palette (dark mode)**

| Token | Hex | Usage |
|---|---|---|
| `background` | `#131313` | Window base |
| `surface_container_low` | `#1b1b1c` | Sidebar / panel backgrounds |
| `surface_container` | `#202020` | Card backgrounds |
| `surface_container_highest` | `#353535` | Input fields, elevated elements |
| `surface_bright` | `#393939` | Active segment controls, hover states |
| `primary` | `#adc6ff` | Accent - buttons, links, toggles |
| `primary_container` | `#4b8eff` | Button gradient endpoint |
| `on_surface` | `#e5e2e1` | Primary text (titles only) |
| `on_surface_variant` | `#c1c6d7` | Body text, labels |
| `outline_variant` | `#414755` | Ghost borders (15% opacity max) |

**Typography** - Inter / SF Pro throughout. Titles: `on_surface` at semibold. Body: `on_surface_variant` at regular, 0.875rem, line-height 1.5.

**Key rules for implementation**
- No 1px solid borders between sections - use tonal background shifts only
- No pure black (`#000000`) - use `surface_container_lowest` (`#0e0e0e`) as deepest surface
- Primary action buttons use a linear gradient from `primary_container` to `primary` at 135°
- Segmented controls: container is `surface_container_lowest`, active segment is `surface_bright`
- List item separation via spacing gaps, not dividers
- Ambient shadows only: `surface_container_lowest` at 40% opacity, 24-40px blur, -5px spread

**Reference images**

Main window:
`https://lh3.googleusercontent.com/aida/ADBb0ujwNWWL2W0tdx2COWfWTiu2iQwtohFTDUtAz8De2QE6N5Psbpq2TDKlN3S_F7V4Novwpke20NS8YaA6TKC4rcIxfl6L80j5AEFXYmB1tccTS_jowXTUbw-1Wwp66JkFVpZKBMNOcsNF6rsEEEs2Q01F3TWnx5uyG1IZUA4w0bMHMKaRXixASD9jtVoZV4aOBiFPbU53mssNArznzHIiQ6ellI2b_NvZ7bc6wwNy3EnXo2McGqpMYCHMo7w4`

Settings screen:
`https://lh3.googleusercontent.com/aida/ADBb0uhrcucOT0KRehwOcOLfbkMQCoWn_8BZkdJPQXKtS5GnueWkyU0b6cC-IN2vegLbOl69udQhpOKNyfoBzVFshuqfN5EUUKbxrFrbTBJLKYNf_PgAUxfQw9AU-tTdSf33eeCZA1_MZfnXCrSuGh9Jt3RMHVFpKvxcv6M14FAfs4g11T2sPn9DeBoSiTxh6WSLUPCDauQpNaV96lKJc8vTraHHjZyuvytPwfaJXZo7p73sYD0yyb5RwoiEyBV4`

---

## Core Features - v1.0

### URL Input
- Single text field accepting any yt-dlp-compatible URL (YouTube primary, but not restricted).
- Paste-and-go: if clipboard contains a URL when the field is focused, it should auto-populate.
- Add button (or Return key) adds the URL to the queue.
- Basic URL validation before adding (must start with `http://` or `https://`).
- Clear field after adding to queue.

### Format Selection
- Two options presented as a segmented control or radio buttons:
  - **Video** - passes `--format bestvideo+bestaudio/best` to yt-dlp. Output format: `.mp4` (via `--merge-output-format mp4`).
  - **Audio only** - passes `--extract-audio --audio-format mp3 --audio-quality 0` to yt-dlp.
- This selection applies globally (all queued items use the same setting).
- This is the only format control in v1.0. The architecture should make it easy to replace this with a per-item format picker in a later version.

### Output Folder
- Persistent preference stored in `UserDefaults`.
- Default: `~/Downloads`.
- Folder picker available in the toolbar.
- Selected path displayed in toolbar, truncated with ellipsis if long.

### Download Queue
- Multiple URLs can be added before or during downloading.
- Downloads run one at a time (sequential, not parallel) in v1.0.
- Each queue item shows:
  - Video thumbnail (fetched from yt-dlp's `--write-thumbnail` or from YouTube's thumbnail URL pattern as a fallback)
  - Video title (resolved after add via a fast `yt-dlp --dump-json` call)
  - Progress bar (0-100%)
  - Download speed and ETA (parsed from yt-dlp stdout)
  - Cancel button (kills the subprocess for that item and removes it from the queue)
- Queue items that complete successfully show a tick and remain visible until the app is relaunched or the user clears them.
- Failed items show an error state with a brief message (e.g. "Video unavailable") and a Retry button.

### Live Progress Parsing
- yt-dlp outputs structured progress lines to stdout in the format:
  `[download]  45.3% of 123.45MiB at 2.50MiB/s ETA 00:30`
- The app must parse these lines in real time using `AsyncStream` over the subprocess stdout pipe.
- Parsed values: percentage, file size, speed, ETA.
- Progress bar and labels update on the main thread via `@MainActor`.

### Completed Downloads
- On success, show a macOS notification: "Download complete: [title]".
- Notification taps open the output folder in Finder at the downloaded file.

---

## Settings

Accessible via `Cmd+,` (standard macOS convention). A simple settings panel with:

| Setting | Default | Notes |
|---|---|---|
| Output folder | `~/Downloads` | Same as toolbar picker - synced |
| Concurrent downloads | 1 | Locked to 1 in v1.0, shown greyed out with "coming soon" |
| Filename template | `%(title)s.%(ext)s` | Editable text field; passed to `--output` |
| Embed thumbnail in audio files | On | Passes `--embed-thumbnail` when in audio mode |
| Embed metadata | On | Passes `--embed-metadata` |

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| yt-dlp not found | Prompt to install (see Dependency Management) |
| Network unavailable | Queue item fails with "No network connection" |
| Video unavailable / private | Queue item fails with yt-dlp's error message, truncated to one line |
| Invalid URL | Inline validation error below input field, item not added to queue |
| Homebrew not installed | Clear message with link to brew.sh |
| yt-dlp process killed externally | Queue item fails gracefully with "Process ended unexpectedly" |

---

## Architecture Notes for Extensibility

These are not v1.0 requirements - they are constraints on how v1.0 must be structured so later features are not blocked.

- **DependencyChecker** - a standalone service responsible for all Homebrew, yt-dlp, and ffmpeg detection, version checking, and installation. No other part of the app calls `brew` directly. Designed so additional dependencies can be registered and checked without changing call sites.
- **YTDLPRunner** - isolate all yt-dlp subprocess invocation in a single service class. All flag-building logic lives here. No other part of the app constructs yt-dlp argument arrays.
- **DownloadItem model** - a single struct/class representing a queued download. Must include a `formatOptions` property (even if v1.0 only writes to it from the global toggle) so per-item format selection can be added without a model refactor.
- **FormatSelector view** - the segmented control must be a standalone SwiftUI view that can be swapped out for a richer format picker in v2.0.
- **ProgressParser** - a standalone parser for yt-dlp stdout lines. Must be unit-testable in isolation.

---

## Out of Scope - v1.0

The following are explicitly deferred. Do not implement or stub these in v1.0:

- Playlist/channel downloading
- Subtitle downloading
- Browser cookie import
- Parallel downloads
- Download history persistence
- Per-item format selection
- Proxy support
- Scheduled downloads

---

## Acceptance Criteria

1. App launches, detects yt-dlp and ffmpeg (or offers to install each), and shows both versions in the status bar.
2. If yt-dlp or ffmpeg is missing and the user declines installation, a persistent warning banner is shown and reappears on next launch.
3. "Remind me tomorrow" on an update banner suppresses it for 24 hours; it reappears on the first launch after that window.
2. Pasting a YouTube URL and pressing Add resolves the title and thumbnail within 3 seconds.
3. Download starts automatically and progress bar updates at least once per second.
4. Completed video appears in the output folder as a `.mp4` file.
5. Completed audio appears as a `.mp3` file with embedded artwork and metadata.
6. Cancelling a download mid-way removes it from the queue and leaves no partial file.
7. Queueing two URLs processes them sequentially - second starts when first completes.
8. A macOS notification fires on completion and opens Finder when tapped.
9. Settings persist across relaunch.
10. App is signed and notarised and opens without a Gatekeeper warning.

---

Version 1.1 - ready for Claude Code.
