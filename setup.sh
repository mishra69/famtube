#!/bin/bash
# FamTube Setup Script
# Installs famtube to ~/famtube and sets up cron jobs

set -euo pipefail

INSTALL_DIR="$HOME/famtube"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== FamTube Setup ==="

# ── Check dependencies ────────────────────────────────────────────
echo ""
echo "Checking dependencies..."

if ! command -v yt-dlp &>/dev/null; then
    echo "ERROR: yt-dlp not found. Install it with: brew install yt-dlp"
    exit 1
fi
echo "  yt-dlp: $(yt-dlp --version)"


# ── Install files ─────────────────────────────────────────────────
echo ""
echo "Installing to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

cp "$SCRIPT_DIR/famtube.sh" "$INSTALL_DIR/famtube.sh"
chmod +x "$INSTALL_DIR/famtube.sh"

# Only copy channels.conf if one doesn't already exist at the destination
if [[ -f "$INSTALL_DIR/channels.conf" ]]; then
    echo "  channels.conf already exists — skipping (not overwriting your subscriptions)"
else
    cp "$SCRIPT_DIR/channels.conf" "$INSTALL_DIR/channels.conf"
    echo "  channels.conf copied"
fi

touch "$INSTALL_DIR/famtube.log"
touch "$INSTALL_DIR/downloaded.txt"
echo "  famtube.sh installed"

# ── Set up cron jobs ──────────────────────────────────────────────
echo ""
echo "Setting up cron jobs..."

CRON_SYNC="0 3 * * * $INSTALL_DIR/famtube.sh"
CRON_UPDATE="0 2 * * 0 /opt/homebrew/bin/brew upgrade yt-dlp"

current_cron=$(crontab -l 2>/dev/null || true)

new_cron="$current_cron"
added=0

if echo "$current_cron" | grep -qF "$INSTALL_DIR/famtube.sh"; then
    echo "  Daily sync cron already set — skipping"
else
    new_cron="${new_cron}${new_cron:+$'\n'}${CRON_SYNC}"
    echo "  Added: daily sync at 3 AM"
    added=1
fi

if echo "$current_cron" | grep -qF "brew upgrade yt-dlp"; then
    echo "  Weekly yt-dlp update cron already set — skipping"
else
    new_cron="${new_cron}${new_cron:+$'\n'}${CRON_UPDATE}"
    echo "  Added: weekly yt-dlp update on Sundays at 2 AM"
    added=1
fi

if [[ $added -eq 1 ]]; then
    echo "$new_cron" | crontab -
    echo "  Cron jobs saved."
fi

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Edit your channel subscriptions: $INSTALL_DIR/channels.conf"
echo "  2. Run a manual test: $INSTALL_DIR/famtube.sh"
echo "  3. Check logs: $INSTALL_DIR/famtube.log"
