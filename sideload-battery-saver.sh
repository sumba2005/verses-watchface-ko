#!/bin/bash
set -e
echo "=== Battery Saver Sideloader for vivoactive 4s ==="
PRG="bin/battery-saver.prg"
APP_ID="a1b2c3d4e5f678901234567890123456"

echo "Looking for GARMIN mount..."
MOUNT=$(mount | grep -oE '/(run/media|media|mnt|Volumes)/[^ ]+GARMIN[^ ]*' | head -1 || echo "")

if [ -n "$MOUNT" ] && [ -d "$MOUNT" ]; then
  APP_DIR="$MOUNT/APPS/$APP_ID"
  mkdir -p "$APP_DIR"
  cp -f "$PRG" "$APP_DIR/battery-saver.prg"
  echo "Sideloading SUCCESS: $PRG copied to $APP_DIR/"
  echo "Safely eject watch, reboot it, then hold UP to select 'Battery Saver'."
else
  echo "No GARMIN mount found. Current mounts:"
  mount | grep -E 'media|mnt|GARMIN|vivo' || lsblk -o NAME,MOUNTPOINT,LABEL
  echo ""
  echo "Manual command example (replace YOUR_MOUNT with actual from lsblk):"
  echo "mkdir -p YOUR_MOUNT/APPS/$APP_ID && cp $PRG YOUR_MOUNT/APPS/$APP_ID/"
  echo "Then reboot watch."
fi
