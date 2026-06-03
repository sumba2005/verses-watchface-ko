#!/usr/bin/env bash
# Sideload a verses watch face onto a USB-connected Garmin device.
#
#   ./tools/sideload.sh [lang]      (default: kor)
#
# Per-language builds have distinct app ids, so each installs under its own
# on-watch filename and they coexist:
#   kor -> bin/verses-kor[-4s].prg  -> GARMIN/APPS/VERSESWF.PRG  (legacy name kept)
#   eng -> bin/verses-eng[-4s].prg  -> GARMIN/APPS/VERSESEN.PRG
# Supports both USB mass-storage (older devices) and MTP/gvfs (vivoactive4/4s).
set -euo pipefail

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
LANG="${1:-kor}"
case "$LANG" in
    kor) APPNAME="VERSESWF.PRG" ;;
    eng) APPNAME="VERSESEN.PRG" ;;
    *)   APPNAME="VERSES${LANG^^}.PRG" ;;
esac

pick_src() {  # $1 = model description text
    if echo "$1" | grep -qi "4S"; then
        echo "$PROJ/bin/verses-$LANG-4s.prg"
    else
        echo "$PROJ/bin/verses-$LANG.prg"
    fi
}

# ---- Path 1: USB mass-storage drive (GARMIN/GarminDevice.xml on a mount) ----
for base in "/media/$USER" "/run/media/$USER" /media /mnt; do
    [ -d "$base" ] || continue
    while IFS= read -r d; do
        XML="$d/GARMIN/GarminDevice.xml"; [ -f "$XML" ] || XML="$d/GarminDevice.xml"
        [ -f "$XML" ] || continue
        APPS="$d/GARMIN/APPS"; [ -d "$APPS" ] || APPS="$d/GARMIN/Apps"
        SRC="$(pick_src "$(cat "$XML")")"
        echo "✅ Mass-storage device: $d"
        echo "✅ Build: $(basename "$SRC")"
        cp "$SRC" "$APPS/$APPNAME"; sync
        echo "✅ Copied to $APPS/$APPNAME — safely eject the watch."
        exit 0
    done < <(find "$base" -maxdepth 2 -type d 2>/dev/null)
done

# ---- Path 2: MTP via gvfs/gio (vivoactive4/4s) ----
DEV="$(gio mount -li 2>/dev/null | grep -oE 'mtp://[^ ]*Garmin[^ ]*' | head -1)"
[ -z "$DEV" ] && DEV="$(mount 2>/dev/null | grep -oE 'mtp:host=091e_[0-9a-f_]+' | head -1)"
[ -n "$DEV" ] && [[ "$DEV" != mtp://* ]] && DEV="mtp://${DEV#mtp:host=}"
# Fallback: scan gvfs dir for a Garmin MTP host (vendor id 091e).
if [ -z "$DEV" ]; then
    host="$(ls "/run/user/$(id -u)/gvfs" 2>/dev/null | grep -oE 'mtp:host=091e_[0-9a-f_]+' | head -1)"
    [ -n "$host" ] && DEV="mtp://${host#mtp:host=}"
fi

if [ -z "$DEV" ]; then
    echo "❌ No Garmin device found (neither mass-storage nor MTP)."
    echo "   Plug the watch in via USB, unlock it, and re-run."
    exit 1
fi
echo "✅ MTP device: $DEV"

XML="$(gio cat "$DEV/Primary/GARMIN/GarminDevice.xml" 2>/dev/null || true)"
SRC="$(pick_src "$XML")"
echo "✅ Model: $(echo "$XML" | grep -oiE 'vívoactive ?4S?|vivoactive ?4S?' | head -1)  ->  $(basename "$SRC")"

DEST="$DEV/Primary/GARMIN/APPS/$APPNAME"
gio remove "$DEST" 2>/dev/null || true   # MTP needs delete-before-overwrite
gio copy "$SRC" "$DEST"
echo "✅ Installed $(stat -c%s "$SRC") bytes to APPS/$APPNAME."
echo "   Unplug the watch — it installs the new face on disconnect."
