# Bink Converter

Convert MP4 to Bink 1 (`.bik`) using GitHub Actions Windows runners. RAD Game
Tools' encoder is Windows-only — this repo wraps the free download in a
reusable GitHub Action.

## Why this exists

The Bink 1 (`.bik`) encoder is `radvideo64.exe`, a Windows GUI binary. It is
the **only** free encoder that exists for Bink 1. Running it on macOS
Apple Silicon in 2026 requires Wine, which is fragile (see the
[research notes](#research-notes) below for the full saga). This repo takes
a different approach: spin up a real Windows environment on demand via GitHub
Actions, run the encoder there, ship the `.bik` as a downloadable artifact.

## Cost

**Free** if the repo is public (unlimited Windows runner minutes, 14 GB disk
per job, 10 min timeout per job). For a private repo, GitHub's free tier
includes 2,000 min/month — 50 conversions of 5 min each fits comfortably.

## Usage

### One-off: convert a video from a URL

```bash
gh workflow run bink-convert.yml \
  -f input_url="https://example.com/video.mp4" \
  -f output_name="my-video" \
  -f video_bitrate="1000" \
  -f audio_bitrate="128"
```

### Convert a local file

The workflow takes a URL, not a local file. To convert a local file:

```bash
# Option A: upload to a temporary gist, GitHub release, or S3, then pass the URL
gh workflow run bink-convert.yml -f input_url="https://github.com/.../video.mp4" -f output_name="myvideo"

# Option B: use the included convert.sh wrapper (handles upload + download)
./scripts/convert.sh /path/to/local.mp4 myvideo 1000 128
```

### Download the .bik output

```bash
# List artifacts from the latest run
gh run list --workflow=bink-convert --limit=1

# Download the .bik from a specific run
gh run download <run-id> --name myvideo.bik
```

The `.bik` file will be in your current directory.

## What's in this repo

- `.github/workflows/bink-convert.yml` — the workflow that runs the encoder
- `.github/radtools-checksum.txt` — pinned SHA1 of `RADTools.7z` (regenerated
  on first run; used as cache key)
- `scripts/convert.sh` — local wrapper to upload a file and trigger the workflow
- `test-fixtures/sample.mp4` — small test file (added by first run, not committed)
- `README.md` — this file

## Parameters

| Input | Default | Description |
|---|---|---|
| `input_url` | test fixture | URL to the MP4 (http/https) |
| `output_name` | `output` | Filename without `.bik` extension |
| `video_bitrate` | `1000` | Video bitrate in kbps (200-5000) |
| `audio_bitrate` | `128` | Audio bitrate in kbps (0 = no audio) |
| `format` | `1` | `1` for Bink 1 (`.bik`), `2` for Bink 2 (`.bk2`) |

## Research notes

This approach is the answer to a long debugging session trying to get
`radvideo64.exe` to run on macOS Apple Silicon in 2026. The full research
writeup (covering Wine 7.7, Wine 11.10, the PE subsystem byte trick, Gcenx's
macOS Wine builds, and why each one failed) is in the original problem
writeup at `~/.hermes/projects/harness-experimental/promotion/bink-encoder-research.md`
on the original developer's machine.

TL;DR of why GitHub Actions works where Wine-on-macOS doesn't:

1. **Real Windows environment.** DirectShow + Windows Media Foundation are
   present, so MP4 import works natively. No QuickTime compatibility issues.
2. **No graphics subsystem fight.** `radvideo64.exe` is a GUI app, but Windows
   has no concept of "loading MoltenVK before starting" — the GUI subsystem
   is always present.
3. **Reproducible.** Every run starts from a clean image, installs the same
   pinned RAD Tools version, produces a verified `.bik` file.
4. **Snapshotted via cache.** The `actions/cache` step caches the extracted
   `radvideo64.exe` across runs, so warm runs skip the download + extract.

## Limitations

- **10 minute job timeout.** A 1-hour 1080p MP4 at 1000 kbps will take ~6
  minutes to encode. Anything longer than ~1.5 hours will time out. For longer
  videos, lower the bitrate or split the input first.
- **2 GB artifact limit.** A 1-hour 1080p `.bik` at 1000 kbps is ~450 MB. A
  very long high-bitrate video could exceed the limit. Split or re-encode.
- **Public repo = unlimited free.** Private repo = 2,000 min/month free.
  Decide based on whether you want the workflow files (and the artifact
  metadata) to be public.
- **MP4 files only.** Other formats (`.avi`, `.mov`, `.mkv`) work too via
  DirectShow, but the workflow is named "bink-convert" and the input
  defaults to `.mp4`. The encoder itself is format-agnostic.
