#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["openai>=1.0.0"]
# ///
"""
Extract transcript from a local video or audio file.

Tries embedded subtitle tracks first, falls back to OpenAI Whisper API.

Usage:
    uv run scripts/get_local_transcript.py <file_path> [--timestamps] [--sub-track N]
"""

import sys
import os
import json
import re
import argparse
import subprocess
import tempfile
from pathlib import Path


def probe_subtitle_streams(file_path: str) -> list[dict]:
    """Probe file for embedded subtitle streams using ffprobe."""
    result = subprocess.run(
        [
            "ffprobe", "-v", "quiet",
            "-print_format", "json",
            "-show_streams",
            "-select_streams", "s",
            file_path,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        return []
    data = json.loads(result.stdout)
    return data.get("streams", [])


def extract_embedded_subs(file_path: str, track: int, with_timestamps: bool) -> str:
    """Extract embedded subtitle track as SRT, then parse."""
    result = subprocess.run(
        [
            "ffmpeg", "-v", "quiet",
            "-i", file_path,
            "-map", f"0:s:{track}",
            "-f", "srt",
            "-",
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to extract subtitle track {track}")
    return parse_srt(result.stdout, with_timestamps)


def parse_srt(srt_text: str, with_timestamps: bool) -> str:
    """Parse SRT formatted text into plain or timestamped lines."""
    lines: list[str] = []
    timestamp_pattern = re.compile(
        r"(\d{2}):(\d{2}):(\d{2}),\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}"
    )

    current_timestamp = ""
    for line in srt_text.strip().splitlines():
        line = line.strip()
        if not line or line.isdigit():
            continue
        match = timestamp_pattern.match(line)
        if match:
            h, m, s = int(match.group(1)), int(match.group(2)), int(match.group(3))
            if h > 0:
                current_timestamp = f"[{h:02d}:{m:02d}:{s:02d}]"
            else:
                current_timestamp = f"[{m:02d}:{s:02d}]"
            continue
        if with_timestamps and current_timestamp:
            lines.append(f"{current_timestamp} {line}")
        else:
            lines.append(line)

    return "\n".join(lines)


def extract_audio_for_whisper(file_path: str, tmp_dir: str) -> str:
    """Extract and compress audio to mono 16kHz opus for Whisper API."""
    audio_path = os.path.join(tmp_dir, "audio.ogg")
    result = subprocess.run(
        [
            "ffmpeg", "-v", "quiet",
            "-i", file_path,
            "-vn",                  # no video
            "-ac", "1",             # mono
            "-ar", "16000",         # 16kHz
            "-c:a", "libopus",
            "-b:a", "32k",          # low bitrate, speech is fine
            audio_path,
        ],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Failed to extract audio: {result.stderr}")
    return audio_path


def transcribe_with_whisper(audio_path: str, with_timestamps: bool) -> str:
    """Send audio to OpenAI Whisper API and return transcript."""
    from openai import OpenAI

    client = OpenAI()
    response_format = "verbose_json" if with_timestamps else "text"

    with open(audio_path, "rb") as f:
        response = client.audio.transcriptions.create(
            model="whisper-1",
            file=f,
            response_format=response_format,
        )

    if not with_timestamps:
        return response

    # verbose_json returns segments with start times
    lines: list[str] = []
    for segment in response.segments:
        seconds = segment["start"]
        h = int(seconds // 3600)
        m = int((seconds % 3600) // 60)
        s = int(seconds % 60)
        ts = f"[{h:02d}:{m:02d}:{s:02d}]" if h > 0 else f"[{m:02d}:{s:02d}]"
        lines.append(f"{ts} {segment['text'].strip()}")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Get transcript from a local video/audio file"
    )
    parser.add_argument("file", help="Path to video or audio file")
    parser.add_argument(
        "--timestamps", "-t", action="store_true",
        help="Include timestamps in output",
    )
    parser.add_argument(
        "--sub-track", type=int, default=0,
        help="Subtitle track index to extract (default: 0)",
    )
    args = parser.parse_args()

    file_path = os.path.abspath(args.file)
    if not os.path.isfile(file_path):
        print(f"Error: File not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    # Try embedded subtitles first
    sub_streams = probe_subtitle_streams(file_path)
    if sub_streams:
        track = min(args.sub_track, len(sub_streams) - 1)
        print(
            f"Found {len(sub_streams)} subtitle track(s), extracting track {track}...",
            file=sys.stderr,
        )
        transcript = extract_embedded_subs(file_path, track, args.timestamps)
        print(transcript)
        return

    # Fall back to Whisper API
    if not os.environ.get("OPENAI_API_KEY"):
        print(
            "Error: No embedded subtitles found and OPENAI_API_KEY is not set.",
            file=sys.stderr,
        )
        sys.exit(1)

    print("No embedded subtitles found, transcribing with Whisper API...", file=sys.stderr)
    with tempfile.TemporaryDirectory() as tmp_dir:
        audio_path = extract_audio_for_whisper(file_path, tmp_dir)
        size_mb = os.path.getsize(audio_path) / (1024 * 1024)
        print(f"Audio extracted ({size_mb:.1f} MB), sending to Whisper...", file=sys.stderr)

        if size_mb > 25:
            print(
                "Error: Compressed audio exceeds 25MB Whisper limit. "
                "Try a shorter file or lower bitrate.",
                file=sys.stderr,
            )
            sys.exit(1)

        transcript = transcribe_with_whisper(audio_path, args.timestamps)
        print(transcript)


if __name__ == "__main__":
    main()
