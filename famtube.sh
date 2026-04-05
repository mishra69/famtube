#!/bin/bash
# FamTube - YouTube channel downloader and manager
# Downloads latest videos from subscribed channels and cleans up old ones
# Designed to run as a daily cron job

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────
FAMTUBE_DIR="/Users/abhishek/Public/FamTube"
CONFIG_FILE="$(dirname "$0")/channels.conf"
LOG_FILE="$(dirname "$0")/famtube.log"
ARCHIVE_FILE="$(dirname "$0")/downloaded.txt"

DEFAULT_MAX_VIDEOS=5
DEFAULT_FORMAT="best[ext=mp4]"

# ── Logging ────────────────────────────────────────────────────
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ── Setup ──────────────────────────────────────────────────────
mkdir -p "$FAMTUBE_DIR"

log "========== FamTube sync started =========="

# ── Parse config and process each channel ──────────────────────
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Parse: channel_url | max_videos | format
    IFS='|' read -r channel_url max_videos format <<< "$line"

    # Trim whitespace
    channel_url="$(echo "$channel_url" | xargs)"
    max_videos="$(echo "${max_videos:-$DEFAULT_MAX_VIDEOS}" | xargs)"
    format="$(echo "${format:-$DEFAULT_FORMAT}" | xargs)"

    # Validate
    if [[ -z "$channel_url" ]]; then
        log "WARN: Skipping empty channel URL"
        continue
    fi

    log "Processing: $channel_url (keep $max_videos, format: $format)"

    # ── Get channel name ───────────────────────────────────────
    # Extract a clean channel name for filenames
    channel_name=$(yt-dlp --print "%(channel)s" --playlist-items 1 "$channel_url/videos" 2>/dev/null || echo "Unknown")
    channel_name=$(echo "$channel_name" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

    if [[ -z "$channel_name" || "$channel_name" == "Unknown" ]]; then
        log "ERROR: Could not resolve channel name for $channel_url, skipping"
        continue
    fi

    log "Channel name: $channel_name"

    # ── Download latest videos ─────────────────────────────────
    # Download up to max_videos most recent, skip already downloaded
    yt-dlp \
        --playlist-items "1:${max_videos}" \
        --output "${FAMTUBE_DIR}/%(upload_date>%Y-%m-%d)s_${channel_name}_%(title)s.%(ext)s" \
        --format "$format" \
        --download-archive "$ARCHIVE_FILE" \
        --no-overwrites \
        --restrict-filenames \
        --quiet \
        --no-warnings \
        "$channel_url/videos" 2>&1 | while read -r dl_line; do
            log "  yt-dlp: $dl_line"
        done

    log "Download complete for $channel_name"

    # ── Cleanup: keep only max_videos per channel ──────────────
    # Find all files for this channel, sorted newest first, delete extras
    file_count=0
    while IFS= read -r filepath; do
        file_count=$((file_count + 1))
        if [[ $file_count -gt $max_videos ]]; then
            filename=$(basename "$filepath")
            log "CLEANUP: Removing old video: $filename"
            rm -f "$filepath"
        fi
    done < <(find "$FAMTUBE_DIR" -maxdepth 1 -name "*_${channel_name}_*" -type f | sort -r)

    log "Kept $((file_count > max_videos ? max_videos : file_count)) of $file_count videos for $channel_name"

done < "$CONFIG_FILE"

# ── Remove empty directories if any ───────────────────────────
find "$FAMTUBE_DIR" -type d -empty -delete 2>/dev/null || true

log "========== FamTube sync complete =========="
