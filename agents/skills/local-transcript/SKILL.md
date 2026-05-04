---
name: local-transcript
description: Extract transcripts from local video/audio files. Use when the user asks for a transcript, subtitles, or captions of a local video or audio file. Tries embedded subtitle tracks first, falls back to OpenAI Whisper API for speech-to-text. Supports output with or without timestamps.
---

# Local Transcript

Extract transcripts from local video and audio files.

## Usage

Run the script with a path to a video or audio file:

```bash
uv run scripts/get_local_transcript.py "/path/to/video.mp4"
```

With timestamps:

```bash
uv run scripts/get_local_transcript.py "/path/to/video.mp4" --timestamps
```

## How It Works

1. **Embedded subtitles** — probes the file with `ffprobe` for subtitle streams. If found, extracts them directly (instant, no API call).
2. **Whisper API fallback** — if no embedded subs, extracts audio via `ffmpeg`, compresses to mono 16kHz opus, and sends to OpenAI's Whisper API for transcription.

## Requirements

- `ffmpeg` and `ffprobe` must be installed and on PATH
- `OPENAI_API_KEY` environment variable must be set (only needed for Whisper fallback)

## Supported Formats

Any format ffmpeg can read: `.mp4`, `.mkv`, `.avi`, `.mov`, `.webm`, `.mp3`, `.m4a`, `.wav`, `.flac`, `.ogg`, etc.

## Output

- CRITICAL: YOU MUST NEVER MODIFY THE RETURNED TRANSCRIPT
- If the transcript is without timestamps, you SHOULD clean it up so that it is arranged by complete paragraphs and the lines don't cut in the middle of sentences.
- If you were asked to save the transcript to a specific file, save it to the requested file.
- If no output file was specified, use the input filename (without extension) with a `-transcript.txt` suffix.

## Notes

- Audio is compressed before upload to stay within Whisper's 25MB limit
- For files with multiple subtitle tracks, extracts the first one by default
- Use `--sub-track N` to select a specific subtitle track (0-indexed)
