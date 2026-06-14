# Bink on CI: status update (June 2026)

This repo exists to investigate whether MP4 → Bink 1 (`.bik`) conversion can
run cleanly on CI. After 4 attempts across 3 platforms, the answer is **no,
not with the free `radvideo64.exe` from RAD Video Tools**.

## What I tried (chronologically)

| # | Platform | Architecture | Result |
|---|---|---|---|
| 1 | GitHub Actions, `windows-latest` (Server 2022) | Real Windows, Session 0 (no interactive desktop) | radvideo64.exe hangs forever. Even with PE subsystem byte patched (GUI → Console) and `cmd /c` to give it a console environment, the encoder doesn't reach the conversion step. |
| 2 | GitHub Actions, `ubuntu-22.04` + Wine 11.10 (apt) + Xvfb | Linux + Wine + virtual display | Wine initializes successfully, RAD Tools extracts, MP4 imports fine. But the encoder itself hangs in the conversion loop after Wine is fully started. Same hang as #1. |
| 3 | (Earlier in this session) macOS Apple Silicon, Wine 7.7 from `game-porting-toolkit` cask | macOS + Wine 7.7 | GUI subsystem hangs in MoltenVK init. |
| 4 | (Earlier in this session) macOS Apple Silicon, Wine 11.10 from Gcenx's macOS_Wine_builds + Xvfb-equivalent | macOS + modern Wine | GUI renders, but the actual conversion requires interactive input. |

All 4 environments hit the same wall: **`radvideo64.exe` is a Windows GUI app that requires an interactive desktop session**. Running it under Wine, headless, in CI, or in any non-interactive environment hits a wall somewhere in the event loop / DirectShow path / codec load.

## The root cause

`radvideo64.exe` is a 30-year-old tool that was designed to be a Windows GUI
app. Even though RAD documented a CLI syntax in the Bink FAQ
(`radvideo64.exe input.mp4 /bink /bink1 output.bik`), that syntax is parsed
inside the GUI's command-line processing, which requires a Windows event
loop, which requires a real (or virtual) interactive desktop session. The
PE subsystem byte (GUI=2, Console=3) only tells the loader which subsystem
DLLs to pre-load — it doesn't change the fact that the actual code paths
call DirectShow + GDI APIs that need a window station.

## What this means for the user

The free `radvideo64.exe` cannot be used in CI, in Wine headless, or in any
non-interactive Windows environment. The actual working approaches are:

1. **Drive the GUI interactively** (the user already has Wine 11.10 set up
   locally on their Mac Studio, the GUI renders, they just need to click
   "Open" + "Bink it!" themselves for each file). This works today.
2. **Use the Bink SDK** (paid, sent by email to licensees). The SDK ships a
   real CLI tool called `binkcl.exe` that has none of the GUI app's
   restrictions. We don't have access to it.
3. **From-scratch Bink 1 encoder** (3-5 month engineering project, the
   first OSS Bink 1 encoder in any language). Reuse FFmpeg's existing
   `libavcodec/bink.c` decoder as the spec reference.
4. **Skip Bink entirely** and use WebM/VP9/AV1. Most game engines in 2026
   play these natively.

## What's in this repo

- `.github/workflows/bink-convert.yml` — the GHA workflow, **doesn't
  actually work end-to-end** (encodes hang). Kept for reference.
- `scripts/convert.sh` — wrapper script that uploads a local file to
  file.io and triggers the workflow. Would work if the workflow worked.
- `test-fixtures/sample.mp4` — 5-second test MP4 committed for the test
  trigger.
- `README.md` — original optimistic description of the approach.

The repo can be deleted (`gh repo delete hoangnb24/bink-converter`) or kept
as a record of what was tried.
