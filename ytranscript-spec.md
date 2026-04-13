# YTTranscript - iOS/iPadOS Transcript Companion
## Product Specification v1.0

**Date:** April 2026
**Purpose:** Complete specification for a native iOS/iPadOS app that fetches and
copies transcripts from YouTube videos. Intended for use with Claude Code.

---

## Overview

A lightweight, native iOS/iPadOS app that fetches transcripts from YouTube videos
without any server-side dependencies or API keys. The user pastes a URL or shares
one from another app, selects a language if needed, and gets a clean readable
transcript they can copy to the clipboard. Designed as a companion to YTGet but
fully standalone.

---

## Tech Stack

- **Language:** Swift
- **UI Framework:** SwiftUI (iOS 17+ target)
- **Transcript fetching:** Native URLSession — scrapes YouTube's caption track data
  from the page source (no yt-dlp, no API key, no backend)
- **Persistence:** None required in v1.0
- **Distribution:** App Store

---

## Transcript Fetching Approach

YouTube embeds caption track URLs in the page source as part of a JSON blob. The
fetch process is:

1. Extract the video ID from the URL
2. Fetch the YouTube page HTML via URLSession
3. Parse out the `captionTracks` array from the embedded `ytInitialPlayerResponse` JSON
4. Select the best matching track for the requested language (prefer manual
   captions over auto-generated)
5. Fetch the caption XML from the track URL
6. Parse and clean the XML through `TranscriptProcessor` (see Shared Code below)

No API key, no Homebrew, no subprocess. This approach is fragile if YouTube
changes its page structure, so the architecture should make the fetching layer
easy to swap out.

---

## Shared Code

`TranscriptProcessor` should be extracted from YTGet into a local Swift Package
(`TranscriptCore`) shared between:
- YTTranscript main app target
- YTTranscript share extension target

`TranscriptProcessor` converts raw caption data into clean readable text,
collapsing duplicate lines and grouping into paragraphs. See YTGet implementation
for reference.

---

## Application Layout

### Main App

Single screen, no navigation stack.

```
+-------------------------------------------------------+
| YTTranscript                                          |
+-------------------------------------------------------+
| URL input field                      [Fetch] button   |
+-------------------------------------------------------+
| Language: [en ▾]                                      |
+-------------------------------------------------------+
|                                                       |
|  Transcript output area (scrollable)                  |
|  # Video Title                                        |
|  url: https://...                                     |
|                                                       |
|  Lorem ipsum...                                       |
|                                                       |
+-------------------------------------------------------+
| [Copy to Clipboard]          [Clear]                  |
+-------------------------------------------------------+
```

### Share Extension

Compact sheet presented over the sharing app. No URL field — the URL is passed
in from the share sheet.

```
+---------------------------+
| YTTranscript              |
| Video Title               |
+---------------------------+
| Lang: [en ▾]  [Fetch]     |
+---------------------------+
|                           |
| Transcript text...        |
|                           |
+---------------------------+
| [Copy]           [Close]  |
+---------------------------+
```

---

## UI Design

### Colour Palette (Dark Mode — matches YTGet "Aqua Graphite")

| Token                       | Hex       | Usage                   |
|-----------------------------|-----------|-------------------------|
| `background`                | `#131313` | Window base             |
| `surface_container`         | `#202020` | Card backgrounds        |
| `surface_container_highest` | `#353535` | Input fields            |
| `surface_bright`            | `#393939` | Active states           |
| `primary`                   | `#adc6ff` | Accent - buttons, links |
| `on_surface`                | `#e5e2e1` | Primary text            |
| `on_surface_variant`        | `#c1c6d7` | Body text, labels       |

Support both light and dark mode, but dark is the primary design target.

### Key Rules
- SF Pro throughout — no custom fonts
- No borders between sections — use tonal background shifts
- Primary action button uses a gradient from `#4b8eff` to `#adc6ff` at 135°

---

## Core Features - v1.0

### URL Input (Main App)
- Single text field accepting YouTube URLs
- Paste-and-go: auto-populate from clipboard on field focus if clipboard contains
  a YouTube URL
- Validates URL before fetching (must be a recognisable YouTube URL pattern)
- Clear field button

### Language Selection
- Compact dropdown/picker showing available language tracks (populated after
  initial page fetch)
- Default: English (`en`)
- Falls back to auto-generated captions if no manual track available for the
  selected language
- If no captions available at all, show a clear error message

### Transcript Output
- Formatted as clean readable text matching YTGet's markdown output:
  - Title as heading
  - Source URL
  - Body text grouped into paragraphs
- Scrollable
- Selectable text

### Copy to Clipboard
- Single tap copies the full transcript text
- Brief confirmation ("Copied") shown after tap

### Share Extension
- Registered for `public.url` type, appearing in the iOS share sheet
- Activated when user shares a YouTube URL from Safari, YouTube app, etc.
- Presents a compact sheet within the sharing app
- Language picker defaults to `en`
- Fetch triggered automatically on load (since URL is already known)
- Copy button copies transcript and dismisses the extension

---

## Error Handling

| Scenario                          | Behaviour                                          |
|-----------------------------------|----------------------------------------------------|
| Invalid / non-YouTube URL         | Inline validation error, fetch blocked             |
| No captions available             | "No transcript available for this video"           |
| Network unavailable               | "No network connection"                            |
| YouTube page structure changed    | "Could not fetch transcript — try again later"     |
| Request timed out                 | "Request timed out — check your connection"        |

---

## Architecture Notes

- **TranscriptFetcher** — standalone service handling all network calls and
  YouTube page parsing. No other part of the app makes network requests directly.
  Designed so the fetching strategy can be swapped (e.g. to an API) without
  changing call sites.
- **TranscriptProcessor** — shared via `TranscriptCore` Swift Package with YTGet.
  Pure Swift, no dependencies.
- **LanguageTrack** — a simple model representing a caption track
  (`code: String, name: String, isAutoGenerated: Bool`). Populated by
  `TranscriptFetcher` and displayed in the language picker.

---

## Out of Scope - v1.0

- Non-YouTube URLs
- Downloading video or audio
- Saving transcripts to Files
- History of previous transcripts
- Background fetching
- iPad split-view optimisation (basic iPad support via adaptive layout is fine)

---

## Acceptance Criteria

1. Pasting a YouTube URL and tapping Fetch returns a clean transcript within 5
   seconds on a normal connection
2. The share extension activates from Safari and the YouTube app
3. Copy to Clipboard copies the full transcript text including title and URL header
4. If no captions are available, a clear message is shown
5. The language picker shows all available tracks for the video
6. Auto-generated captions are clearly labelled as such in the picker
7. The app works correctly in both light and dark mode

---

Version 1.0 — ready for Claude Code.
