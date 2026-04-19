# YTGet Roadmap

Feature ideas and planned work, roughly in priority order.

## Planned

- **AI Summary** — send transcript to an Ollama model running on the local network. Configurable endpoint URL and model picker in Settings. Streaming response with typewriter effect. "Summarise" button on completed transcript queue items.

- **Auto-update check** — on launch, silently check the latest GitHub release against the current version. If a newer version is available, show a non-intrusive banner with Download, Remind Me Tomorrow, and Skip This Version options.

## Ideas / Under Consideration

- **Parallel downloads** — currently locked to sequential; allow configurable concurrency (marked "coming soon" in Settings)
- **Per-item format selection** — currently format is global; allow each queue item to have its own format setting
- **Include video description in transcript** — option to prepend the video's description text to the transcript markdown file; description is already available from the `--dump-json` info fetch so no extra yt-dlp call needed
- **File size display** — file size is already parsed from yt-dlp output but not shown in the queue item row; small addition to surface it alongside speed and ETA
- **Playlist / channel downloading** — download all videos from a playlist or channel URL
- **Browser cookie import** — pass browser cookies to yt-dlp for age-restricted or member-only content
- **Proxy support** — configurable proxy for yt-dlp downloads
- **Scheduled downloads** — queue downloads to start at a specified time
- **iOS/iPadOS companion app** — YTTranscript, transcript-only companion (spec drafted separately)
