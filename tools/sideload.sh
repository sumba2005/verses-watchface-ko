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
    kor) APPNAME="VERSESWF.PRG"; WIDGETNAME="VERSEWKR.PRG" ;;
    eng) APPNAME="VERSESEN.PRG"; WIDGETNAME="VERSEWEN.PRG" ;;
    *)   APPNAME="VERSES${LANG^^}.PRG"; WIDGETNAME="VERSEW${LANG^^}.PRG" ;;
esac

pick_src() {  # $1 = full GarminDevice.xml contents (or model text)
    local xml_or_model="$1"
    local file_lang="$LANG"
    if [ "$file_lang" = "eng" ]; then
        file_lang="face"
    fi

    # Try matching direct ModelName or Description from GarminDevice.xml
    local model_name=""
    model_name=$(echo "$xml_or_model" | grep -oP '(?<=<ModelName>)[^<]+' | head -1 | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n_-' || true)
    if [ -z "$model_name" ]; then
        model_name=$(echo "$xml_or_model" | grep -oP '(?<=<Description>)[^<]+' | head -1 | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n_-' || true)
    fi

    if [ -n "$model_name" ]; then
        # Check direct model suffix candidate
        local candidate="$PROJ/bin/verses-$file_lang-$model_name.prg"
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
        # Check vivoactive+suffix candidate (e.g. if XML says '4' but file is 'vivoactive4')
        local candidate_va="$PROJ/bin/verses-$file_lang-vivoactive$model_name.prg"
        if [ -f "$candidate_va" ]; then
            echo "$candidate_va"
            return 0
        fi
    fi

    # Build a candidate list of device suffixes we know how to build (from bin/ + common aliases)
    # We prefer the most specific match that actually exists on disk.
    local candidates=()

    # 1. Direct model hints from the XML (product ids and human names)
    local hints
    hints=$(echo "$xml_or_model" | tr '[:upper:]' '[:lower:]' | grep -oE '(vivoactive ?[0-9s]*|venu ?[0-9s]*|fenix ?[0-9sxpro]*|epix ?[0-9pro]*|fr ?[0-9]+s?|venusq ?[0-9m]*|forerunner ?[0-9]+s?|instinct ?[0-9sx]*)' | tr -d ' ' | sort -u || true)

    for h in $hints; do
        # Map human-ish names to the exact product-id suffixes we use in filenames
        case "$h" in
            vivoactive4|va4)               candidates+=("vivoactive4") ;;
            vivoactive5|va5)               candidates+=("vivoactive5") ;;
            venu3s)                        candidates+=("venu3s") ;;
            venu3)                         candidates+=("venu3") ;;
            venu2s)                        candidates+=("venu2s") ;;
            venu2)                         candidates+=("venu2") ;;
            venu)                          candidates+=("venu") ;;
            fenix7xpro|fenix7x)            candidates+=("fenix7xpro" "fenix7x") ;;
            fenix7spro|fenix7s)            candidates+=("fenix7spro" "fenix7s") ;;
            fenix7pro|fenix7)              candidates+=("fenix7pro" "fenix7") ;;
            fenix6xpro)                    candidates+=("fenix6xpro") ;;
            fenix6spro|fenix6s)            candidates+=("fenix6spro" "fenix6s") ;;
            fenix6pro|fenix6)              candidates+=("fenix6pro" "fenix6") ;;
            fenix843mm|fenix8_43)          candidates+=("fenix843mm") ;;
            fenix847mm|fenix8_47)          candidates+=("fenix847mm") ;;
            epix2pro47|epix2pro)           candidates+=("epix2pro47mm") ;;
            epix2)                         candidates+=("epix2") ;;
            epix)                          candidates+=("epix") ;;
            fr965)                         candidates+=("fr965") ;;
            fr955)                         candidates+=("fr955") ;;
            fr265s)                        candidates+=("fr265s") ;;
            fr265)                         candidates+=("fr265") ;;
            fr255s)                        candidates+=("fr255s") ;;
            venusq2m)                      candidates+=("venusq2m") ;;
            venusq2)                       candidates+=("venusq2") ;;
            venusq)                        candidates+=("venusq") ;;
            instinct2s)                    candidates+=("instinct2s") ;;
            instinct2)                     candidates+=("instinct2") ;;
        esac
    done

    # 2. Always consider the full product ids that are present as files (catches anything we missed)
    for f in "$PROJ"/bin/verses-kor-*.prg; do
        [ -f "$f" ] || continue
        base=$(basename "$f" .prg)
        suf=${base#verses-kor-}
        # skip the bare "verses-kor.prg" if it exists
        [ "$suf" = "kor" ] && continue
        candidates+=("$suf")
    done

    # 3. Try candidates in order; first one that has a real file wins
    for suf in "${candidates[@]}"; do
        for variant in "$suf" "vivoactive$suf"; do
            local candidate="$PROJ/bin/verses-$file_lang-$variant.prg"
            if [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
    done

    # 4. Ultimate fallbacks that are very likely to exist
    if [ -f "$PROJ/bin/verses-$file_lang.prg" ]; then
        echo "$PROJ/bin/verses-$file_lang.prg"
        return 0
    fi
    if [ -f "$PROJ/bin/verses-$file_lang-vivoactive5.prg" ]; then
        echo "$PROJ/bin/verses-$file_lang-vivoactive5.prg"
        return 0
    fi
    # Last resort (may not exist)
    echo "$PROJ/bin/verses-$file_lang.prg"
}

pick_widget() {  # $1 = full GarminDevice.xml contents (or model text)
    local xml_or_model="$1"
    local wlang="$LANG"

    # Try matching direct ModelName or Description from GarminDevice.xml
    local model_name=""
    model_name=$(echo "$xml_or_model" | grep -oP '(?<=<ModelName>)[^<]+' | head -1 | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n_-' || true)
    if [ -z "$model_name" ]; then
        model_name=$(echo "$xml_or_model" | grep -oP '(?<=<Description>)[^<]+' | head -1 | tr '[:upper:]' '[:lower:]' | tr -d ' \t\r\n_-' || true)
    fi

    if [ -n "$model_name" ]; then
        # Check direct model suffix candidate
        local candidate="$PROJ/bin/verses-widget-$wlang-$model_name.prg"
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
        # Check vivoactive+suffix candidate
        local candidate_va="$PROJ/bin/verses-widget-$wlang-vivoactive$model_name.prg"
        if [ -f "$candidate_va" ]; then
            echo "$candidate_va"
            return 0
        fi
    fi

    # Fallback candidates using the same regex mapping
    local candidates=()
    local hints
    hints=$(echo "$xml_or_model" | tr '[:upper:]' '[:lower:]' | grep -oE '(vivoactive ?[0-9s]*|venu ?[0-9s]*|fenix ?[0-9sxpro]*|epix ?[0-9pro]*|fr ?[0-9]+s?|venusq ?[0-9m]*|forerunner ?[0-9]+s?|instinct ?[0-9sx]*)' | tr -d ' ' | sort -u || true)

    for h in $hints; do
        case "$h" in
            vivoactive4|va4)               candidates+=("vivoactive4") ;;
            vivoactive5|va5)               candidates+=("vivoactive5") ;;
            venu3s)                        candidates+=("venu3s") ;;
            venu3)                         candidates+=("venu3") ;;
            venu2s)                        candidates+=("venu2s") ;;
            venu2)                         candidates+=("venu2") ;;
            venu)                          candidates+=("venu") ;;
            fenix7xpro|fenix7x)            candidates+=("fenix7xpro" "fenix7x") ;;
            fenix7spro|fenix7s)            candidates+=("fenix7spro" "fenix7s") ;;
            fenix7pro|fenix7)              candidates+=("fenix7pro" "fenix7") ;;
            fenix6xpro)                    candidates+=("fenix6xpro") ;;
            fenix6spro|fenix6s)            candidates+=("fenix6spro" "fenix6s") ;;
            fenix6pro|fenix6)              candidates+=("fenix6pro" "fenix6") ;;
            fenix843mm|fenix8_43)          candidates+=("fenix843mm") ;;
            fenix847mm|fenix8_47)          candidates+=("fenix847mm") ;;
            epix2pro47|epix2pro)           candidates+=("epix2pro47mm") ;;
            epix2)                         candidates+=("epix2") ;;
            epix)                          candidates+=("epix") ;;
            fr965)                         candidates+=("fr965") ;;
            fr955)                         candidates+=("fr955") ;;
            fr265s)                        candidates+=("fr265s") ;;
            fr265)                         candidates+=("fr265") ;;
            fr255s)                        candidates+=("fr255s") ;;
            venusq2m)                      candidates+=("venusq2m") ;;
            venusq2)                       candidates+=("venusq2") ;;
            venusq)                        candidates+=("venusq") ;;
            instinct2s)                    candidates+=("instinct2s") ;;
            instinct2)                     candidates+=("instinct2") ;;
        esac
    done

    # Fallback: check files present in the bin/ folder
    for f in "$PROJ"/bin/verses-widget-$wlang-*.prg; do
        [ -f "$f" ] || continue
        base=$(basename "$f" .prg)
        suf=${base#verses-widget-$wlang-}
        [ "$suf" = "$wlang" ] && continue
        candidates+=("$suf")
    done

    for suf in "${candidates[@]}"; do
        for variant in "$suf" "vivoactive$suf"; do
            local candidate="$PROJ/bin/verses-widget-$wlang-$variant.prg"
            if [ -f "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
    done

    # The build-all.sh creates an alias for the common case
    if [ -f "$PROJ/bin/verses-widget-$wlang.prg" ]; then
        echo "$PROJ/bin/verses-widget-$wlang.prg"
        return 0
    fi

    # Any widget at all
    ls "$PROJ"/bin/verses-widget-$wlang-*.prg 2>/dev/null | head -1 || echo "$PROJ/bin/verses-widget-$wlang.prg"
}

# ---- Path 1: USB mass-storage drive (GARMIN/GarminDevice.xml on a mount) ----
for base in "/media/$USER" "/run/media/$USER" /media /mnt; do
    [ -d "$base" ] || continue
    while IFS= read -r d; do
        XML="$d/GARMIN/GarminDevice.xml"; [ -f "$XML" ] || XML="$d/GarminDevice.xml"
        [ -f "$XML" ] || continue
        APPS="$d/GARMIN/APPS"; [ -d "$APPS" ] || APPS="$d/GARMIN/Apps"
        local xml_content
        xml_content=$(cat "$XML" 2>/dev/null || true)
        SRC="$(pick_src "$xml_content")"
        echo "✅ Mass-storage device: $d"
        echo "✅ Build: $(basename "$SRC")"
        cp "$SRC" "$APPS/$APPNAME"
        WIDGET_SRC="$(pick_widget "$xml_content")"
        if [ -f "$WIDGET_SRC" ]; then
            cp "$WIDGET_SRC" "$APPS/$WIDGETNAME"
            echo "✅ Widget: $(basename "$WIDGET_SRC") -> APPS/$WIDGETNAME"
        fi
        sync
        echo "✅ Sideload complete — safely eject the watch."
        exit 0
    done < <(find "$base" -maxdepth 2 -type d 2>/dev/null)
done

# ---- Path 2: MTP via gvfs/gio (vivoactive4/4s) ----
DEV="$(gio mount -li 2>/dev/null | grep -oE 'mtp://[^ ]*Garmin[^ ]*' | head -1 || true)"
[ -z "$DEV" ] && DEV="$(mount 2>/dev/null | grep -oE 'mtp:host=091e_[0-9a-f_]+' | head -1 || true)"
[ -n "$DEV" ] && [[ "$DEV" != mtp://* ]] && DEV="mtp://${DEV#mtp:host=}"
# Fallback: scan gvfs dir for a Garmin MTP host (vendor id 091e).
if [ -z "$DEV" ]; then
    host="$(ls "/run/user/$(id -u)/gvfs" 2>/dev/null | grep -oE 'mtp:host=091e_[0-9a-f_]+' | head -1 || true)"
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
MODEL_HINT=$(echo "$XML" | grep -oE 'ModelName|DeviceName|ProductName' -A1 | head -3 | tr '\n' ' ' | tr -s ' ' || echo "unknown")
echo "✅ Model: $MODEL_HINT -> $(basename "$SRC")"

DEST="$DEV/Primary/GARMIN/APPS/$APPNAME"
gio remove "$DEST" 2>/dev/null || true   # MTP needs delete-before-overwrite
gio copy "$SRC" "$DEST"
echo "✅ Installed $(stat -c%s "$SRC") bytes to APPS/$APPNAME."

WIDGET_SRC="$(pick_widget "$XML")"
if [ -f "$WIDGET_SRC" ]; then
    WIDGET_DEST="$DEV/Primary/GARMIN/APPS/$WIDGETNAME"
    gio remove "$WIDGET_DEST" 2>/dev/null || true
    gio copy "$WIDGET_SRC" "$WIDGET_DEST"
    echo "✅ Installed $(stat -c%s "$WIDGET_SRC") bytes to APPS/$WIDGETNAME."
fi

echo "   Unplug the watch — it installs the new apps on disconnect."
