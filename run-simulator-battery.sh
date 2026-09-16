#!/bin/bash
# Connect IQ Simulator Runner for Battery Saver Watchface
# Usage:
#   ./run-simulator-battery.sh [device] [options]
# Options:
#   -f, --font <2|3|4|5>       Set font size (2=Small, 3=Medium, 4=Large, 5=Extra Large)
#   -e, --flash                Enable Flash Saver
#   --no-flash                 Disable Flash Saver
#   -i, --interval <2|5|10|15|30> Set Flash Interval in seconds
#
# Examples:
#   ./run-simulator-battery.sh epix2 --flash --interval 2 --font 5
#   ./run-simulator-battery.sh vivoactive4 -f 4

set -euo pipefail

# 1. Locate Connect IQ SDK
SDK_BIN=""
if command -v monkeyc >/dev/null 2>&1; then
    SDK_BIN=$(dirname "$(command -v monkeyc)")
else
    for cand in \
        "$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin" \
        "$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b/bin" \
        "/home/jkim/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin"
    do
        if [ -d "$cand" ] && [ -x "$cand/monkeyc" ]; then
            SDK_BIN="$cand"
            break
        fi
    done
fi

if [ -z "$SDK_BIN" ]; then
    echo "ERROR: Connect IQ SDK not found. Please set PATH or install SDK."
    exit 1
fi

export PATH="$SDK_BIN:$PATH"
KEY="developer_key"
JUNGLE="battery-saver.jungle"
FAILED_FILE="failed_target.txt"
PRG_PREFIX="battery-saver"

# Default settings overrides
SET_FONT=3
SET_FLASH="false"
SET_INTERVAL=5

DEVICE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--font|--fontSize)
            SET_FONT="$2"
            shift 2
            ;;
        -e|--flash|--enableFlash|--enableFlashSaver)
            SET_FLASH="true"
            shift
            ;;
        --no-flash)
            SET_FLASH="false"
            shift
            ;;
        -i|--interval|--flashInterval|--enableFlashInterval)
            SET_INTERVAL="$2"
            SET_FLASH="true"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./run-simulator-battery.sh [device] [options]"
            echo "Options:"
            echo "  -f, --font <2|3|4|5>          Font size (2=Small, 3=Medium, 4=Large, 5=Extra Large)"
            echo "  -e, --flash                   Enable Flash Saver (1s on every N seconds)"
            echo "  --no-flash                    Disable Flash Saver"
            echo "  -i, --interval <2|5|10|15|30> Set Flash Interval (also enables flash saver)"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$DEVICE" ]; then
                DEVICE="$1"
            fi
            shift
            ;;
    esac
done

# Manage Simulator Process
SIMULATOR_STARTED=0
if ! pgrep -x "simulator" > /dev/null && ! pgrep -f "connectiq" > /dev/null; then
    echo "Starting Connect IQ Simulator..."
    connectiq &
    SIMULATOR_STARTED=1
    sleep 4
fi

stop_simulator() {
    if [ "$SIMULATOR_STARTED" -eq 1 ]; then
        echo "Stopping simulator..."
        pkill -x "simulator" 2>/dev/null || true
        pkill -f "connectiq" 2>/dev/null || true
        SIMULATOR_STARTED=0
    fi
}

get_devices() {
    grep '<iq:product id=' manifest-battery-saver.xml | sed 's/.*id="//;s/".*//' | sort -u
}

get_available_devices() {
    local all_devices=($(get_devices))
    local available=()
    for d in "${all_devices[@]}"; do
        if ! grep -qxF "$d" "$FAILED_FILE" 2>/dev/null; then
            available+=("$d")
        fi
    done
    printf '%s\n' "${available[@]}"
}

ask_pass_fail() {
    local dev="$1"
    echo ""
    echo "======================================"
    local result=""
    while true; do
        read -rp "Test result for $dev — [p]ass / [f]ail / [q]uit: " result
        case "${result,,}" in
            p|pass)
                echo "PASS recorded for $dev."
                echo "======================================"
                return 0 ;;
            f|fail)
                echo "$dev" >> "$FAILED_FILE"
                echo "FAIL recorded for $dev in $FAILED_FILE."
                echo "======================================"
                return 1 ;;
            q|quit)
                echo "Quitting."
                stop_simulator
                exit 0 ;;
            *)
                echo "Please enter p, f or q." ;;
        esac
    done
}

update_settings_json() {
    local json_file="$1"
    if [ -f "$json_file" ]; then
        python3 -c "
import json, sys
fpath = sys.argv[1]
font = int(sys.argv[2])
enable_flash = sys.argv[3].lower() == 'true'
interval = int(sys.argv[4])

try:
    with open(fpath, 'r') as f:
        data = json.load(f)

    for s in data.get('settings', []):
        k = s.get('key')
        if k == 'TimeFontSize':
            s['defaultValue'] = font
        elif k == 'EnableFlashSaver':
            s['defaultValue'] = enable_flash
        elif k == 'FlashInterval':
            s['defaultValue'] = interval

    with open(fpath, 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    pass
" "$json_file" "$SET_FONT" "$SET_FLASH" "$SET_INTERVAL"
    fi
}

run_device() {
    local target_dev="$1"
    local PRG="bin/${PRG_PREFIX}-${target_dev}.prg"
    local SETTINGS_JSON="bin/${PRG_PREFIX}-${target_dev}-settings.json"

    mkdir -p bin

    if [ ! -f "$PRG" ]; then
        echo "Building for $target_dev..."
        monkeyc -f "$JUNGLE" -d "$target_dev" -o "$PRG" -y "$KEY" -w || echo "Build had warnings."
    fi

    if [ ! -f "$PRG" ]; then
        echo "Build failed for $target_dev."
        echo "$target_dev" >> "$FAILED_FILE"
        return 1
    fi

    update_settings_json "$SETTINGS_JSON"

    echo ""
    echo ">>> Running $PRG on simulator for '$target_dev'..."
    echo "    Settings: Font Size=$SET_FONT | Flash Saver=$SET_FLASH | Interval=${SET_INTERVAL}s"
    echo "(Press Ctrl+C to stop simulation and return)"
    echo ""

    trap '' SIGINT
    if [ -f "$SETTINGS_JSON" ]; then
        monkeydo "$PRG" "$target_dev" -a "$SETTINGS_JSON:SETTINGS.JSON" || true
    else
        monkeydo "$PRG" "$target_dev" || true
    fi
    trap 'echo ""; stop_simulator; echo "Session interrupted."; exit 130' SIGINT
}

trap 'echo ""; stop_simulator; echo "Session interrupted."; exit 130' SIGINT

# Execution Mode: Direct Device vs Interactive Menu
if [ -n "$DEVICE" ]; then
    echo "Battery Saver Simulator — Direct Target: $DEVICE"
    run_device "$DEVICE"
    ask_pass_fail "$DEVICE" || true
    stop_simulator
    exit 0
fi

echo "Battery Saver Simulator (interactive mode)"
echo "Failed skipped: $(cat $FAILED_FILE 2>/dev/null | wc -l || echo 0) devices."
echo ""

while true; do
    mapfile -t AVAILABLE < <(get_available_devices)
    if [ ${#AVAILABLE[@]} -eq 0 ]; then
        echo "No remaining devices (all marked failed)."
        read -rp "Clear $FAILED_FILE and restart? [y/N]: " clr
        if [[ "$clr" =~ ^[yY]$ ]]; then
            > "$FAILED_FILE"
            echo "Failed file cleared."
            continue
        fi
        break
    fi

    echo "Popular targets: epix2 (AMOLED), vivoactive4 (MIP), fr265 (AMOLED), fenix7 (MIP)"
    read -rp "Enter device name or filter (or press Enter to list all ${#AVAILABLE[@]} devices, q to quit): " query

    if [[ "$query" =~ ^[qQ]$ ]]; then
        stop_simulator
        exit 0
    fi

    SELECTED_DEVICE=""
    if [ -z "$query" ]; then
        echo "Select device to test:"
        for i in "${!AVAILABLE[@]}"; do
            echo "  $((i+1))) ${AVAILABLE[$i]}"
        done
        echo "  q) Quit"
        echo ""

        read -rp "Choice [# or q]: " choice
        if [[ "$choice" =~ ^[qQ]$ ]]; then
            stop_simulator
            exit 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#AVAILABLE[@]}" ]; then
            SELECTED_DEVICE="${AVAILABLE[$((choice-1))]}"
        else
            echo "Invalid choice."
            continue
        fi
    else
        matches=()
        for d in "${AVAILABLE[@]}"; do
            if [[ "$d" == *"$query"* ]]; then
                matches+=("$d")
            fi
        done

        if [ ${#matches[@]} -eq 1 ]; then
            SELECTED_DEVICE="${matches[0]}"
        elif [ ${#matches[@]} -gt 1 ]; then
            echo "Multiple matches found for '$query':"
            for i in "${!matches[@]}"; do
                echo "  $((i+1))) ${matches[$i]}"
            done
            read -rp "Choice [#]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#matches[@]}" ]; then
                SELECTED_DEVICE="${matches[$((choice-1))]}"
            else
                echo "Invalid choice."
                continue
            fi
        else
            echo "No devices matching '$query'."
            continue
        fi
    fi

    # Optional prompt for settings in interactive mode
    read -rp "Customize settings? [y/N]: " cust
    if [[ "$cust" =~ ^[yY]$ ]]; then
        read -rp "Font Size (2=Small, 3=Medium, 4=Large, 5=ExtraLarge) [$SET_FONT]: " f_in
        [ -n "$f_in" ] && SET_FONT="$f_in"
        read -rp "Enable Flash Saver? [y/N] [$SET_FLASH]: " fl_in
        if [[ "$fl_in" =~ ^[yY]$ ]]; then SET_FLASH="true"; elif [[ "$fl_in" =~ ^[nN]$ ]]; then SET_FLASH="false"; fi
        read -rp "Flash Interval in seconds (2, 5, 10, 15, 30) [$SET_INTERVAL]: " int_in
        [ -n "$int_in" ] && SET_INTERVAL="$int_in"
    fi

    run_device "$SELECTED_DEVICE"
    ask_pass_fail "$SELECTED_DEVICE"
    echo "Returning to device selection..."
    echo ""
done

stop_simulator
echo "Simulator closed."
