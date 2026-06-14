#!/usr/bin/env bash
# convert.sh — local wrapper to convert a local MP4 via GitHub Actions.
#
# Usage:
#   ./scripts/convert.sh <input.mp4> [output_name] [video_bitrate_kbps] [audio_bitrate_kbps]
#
# Examples:
#   ./scripts/convert.sh ~/Downloads/clip.mp4
#   ./scripts/convert.sh ~/Downloads/clip.mp4 my-clip 1500 192
#
# What it does:
#   1. Uploads the local file to a temporary public URL via file.io
#   2. Triggers the bink-convert workflow on the hoangnb24/bink-converter repo
#   3. Waits for the workflow to finish
#   4. Downloads the .bik artifact to the current directory
#   5. Cleans up the file.io upload (it auto-deletes after 1 download anyway)
#
# Requires: gh CLI, authenticated to hoangnb24

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <input.mp4> [output_name] [video_bitrate] [audio_bitrate]"
  echo ""
  echo "Example:"
  echo "  $0 ~/Downloads/clip.mp4 my-clip 1000 128"
  exit 1
fi

INPUT="$1"
OUTPUT_NAME="${2:-$(basename "$INPUT" .mp4)}"
VIDEO_BITRATE="${3:-1000}"
AUDIO_BITRATE="${4:-128}"

if [ ! -f "$INPUT" ]; then
  echo "Error: $INPUT not found"
  exit 1
fi

echo "==> Step 1/4: Uploading $INPUT to file.io (free, no account, 1 download limit)..."
FILE_IO_URL=$(curl -s -F "file=@$INPUT" https://file.io | python3 -c "import json,sys; print(json.load(sys.stdin)['link'])")
if [ -z "$FILE_IO_URL" ]; then
  echo "Error: failed to upload to file.io"
  exit 1
fi
echo "    URL: $FILE_IO_URL"

echo ""
echo "==> Step 2/4: Triggering bink-convert workflow..."
RUN_OUTPUT=$(gh workflow run bink-convert.yml \
  -f input_url="$FILE_IO_URL" \
  -f output_name="$OUTPUT_NAME" \
  -f video_bitrate="$VIDEO_BITRATE" \
  -f audio_bitrate="$AUDIO_BITRATE" \
  --repo hoangnb24/bink-converter)
echo "    Triggered."

echo ""
echo "==> Step 3/4: Waiting for workflow to finish (timeout: 9 minutes)..."
RUN_ID=$(gh run list --workflow=bink-convert --repo hoangnb24/bink-converter --limit=1 --json databaseId --jq '.[0].databaseId')
echo "    Run ID: $RUN_ID"

# Wait for completion
gh run watch "$RUN_ID" --repo hoangnb24/bink-converter --exit-status > /dev/null

if ! gh run view "$RUN_ID" --repo hoangnb24/bink-converter --json conclusion --jq '.conclusion' | grep -q "success"; then
  echo "Error: workflow did not succeed. Check:"
  echo "  https://github.com/hoangnb24/bink-converter/actions/runs/$RUN_ID"
  exit 1
fi

echo ""
echo "==> Step 4/4: Downloading .bik artifact..."
gh run download "$RUN_ID" --repo hoangnb24/bink-converter --name "${OUTPUT_NAME}.bik"
mv "${OUTPUT_NAME}.bik" "${OUTPUT_NAME}.bik"
echo ""
echo "Done. Output: $(pwd)/${OUTPUT_NAME}.bik"
ls -lah "${OUTPUT_NAME}.bik"
