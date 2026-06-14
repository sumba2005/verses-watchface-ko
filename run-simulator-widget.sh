#!/bin/bash
# Connect IQ Simulator Runner (Widgets Only)
# Usage:
#   ./run-simulator-widget.sh                 (interactive menu, loops on PASS)
#   ./run-simulator-widget.sh [device]        (run specific widget)

set -euo pipefail

# 1. Locate the SDK bin directory
SDK_BIN=""
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

if [ -z "$SDK_BIN" ]; then
    echo "ERROR: Connect IQ SDK not found. Please verify it is installed."
    exit 1
fi

export PATH="$SDK_BIN:$PATH"

# 2. Check and start simulator if needed
SIMULATOR_STARTED=0
if ! pgrep -x "simulator" > /dev/null && ! pgrep -f "connectiq" > /dev/null; then
    echo "Starting Connect IQ Simulator..."
    connectiq &
    SIMULATOR_STARTED=1
    echo "Waiting for simulator to initialize..."
    sleep 4
fi

stop_simulator() {
    if [ "$SIMULATOR_STARTED" -eq 1 ]; then
        echo "Stopping Connect IQ Simulator..."
        pkill -x "simulator" 2>/dev/null || true
        pkill -f "connectiq" 2>/dev/null || true
        SIMULATOR_STARTED=0
    fi
}

extract_device() {
    local filename
    filename=$(basename "$1" .prg)
    if [[ "$filename" =~ ^verses-widget-kor-(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [ "$filename" = "verses-widget-kor" ]; then
        echo "vivoactive4"
    else
        echo "${filename##*-}"
    fi
}

# Returns 0 for PASS, 1 for FAIL
ask_pass_fail() {
    local prg="$1"
    echo ""
    echo "======================================"
    local result=""
    while true; do
        if [ -t 0 ]; then
            read -rp "Test result — PASS or FAIL? [p/f]: " result < /dev/tty
        else
            result="p"
        fi
        case "${result,,}" in
            p|pass)
                echo "Result: PASS"
                echo "======================================"
                return 0 ;;
            f|fail)
                echo "Result: FAIL"
                local target_name
                target_name=$(basename "$prg" .prg)
                echo "$target_name" >> failed_target.txt
                echo "Recorded '$target_name' in failed_target.txt"
                echo "======================================"
                return 1 ;;
            *) echo "Please enter p (pass) or f (fail)." ;;
        esac
    done
}

if [ $# -eq 0 ]; then
    # Interactive menu mode — loops on PASS, stops on FAIL or Quit
    trap 'echo ""; stop_simulator; exit 130' SIGINT

    while true; do
        all_prg_files=(bin/verses-widget-kor-*.prg)
        if [ ${#all_prg_files[@]} -eq 0 ] || [ ! -e "${all_prg_files[0]}" ]; then
            echo "ERROR: No compiled widget .prg files found in bin/."
            echo "Please run quick-build.sh or compile a widget first."
            stop_simulator
            exit 1
        fi

        # Filter out aliases and failed targets
        prg_files=()
        for f in "${all_prg_files[@]}"; do
            name=$(basename "$f" .prg)
            [[ "$name" = "verses-widget-kor" ]] && continue
            if [ -f failed_target.txt ] && grep -qxF "$name" failed_target.txt; then continue; fi
            prg_files+=("$f")
        done

        if [ ${#prg_files[@]} -eq 0 ]; then
            echo "No remaining widget targets (all failed or none built)."
            break
        fi

        # Pick device
        echo ""
        echo "Select Widget Device:"
        PS3="Device [#]: "
        device_labels=()
        for f in "${prg_files[@]}"; do
            name=$(basename "$f" .prg)
            device_labels+=("${name#verses-widget-kor-}")
        done

        SELECTED_PRG=""
        select dev in "${device_labels[@]}" "Quit"; do
            if [ "$dev" = "Quit" ]; then
                SELECTED_PRG="__quit__"
                break
            elif [ -n "$dev" ]; then
                idx=$(( REPLY - 1 ))
                SELECTED_PRG="${prg_files[$idx]}"
                break
            else
                echo "Invalid selection."
            fi
        done

        [ "$SELECTED_PRG" = "__quit__" ] && break

        DEVICE=$(extract_device "$SELECTED_PRG")
        echo ">>> Running $SELECTED_PRG on simulator device '$DEVICE'..."
        echo "(Press Ctrl+C to stop the simulation and return here)"
        trap '' SIGINT
        monkeydo "$SELECTED_PRG" "$DEVICE" || true
        trap 'echo ""; stop_simulator; exit 130' SIGINT

        if ! ask_pass_fail "$SELECTED_PRG"; then
            stop_simulator
            exit 1
        fi
        # PASS — loop back to menu
    done

    stop_simulator
else
    # Argument mode — single run
    DEVICE="$1"
    SELECTED_PRG="bin/verses-widget-kor-${DEVICE}.prg"

    if [ ! -f "$SELECTED_PRG" ]; then
        # Try without the kor prefix or general aliases if they exist
        if [ -f "bin/verses-widget-${DEVICE}.prg" ]; then
            SELECTED_PRG="bin/verses-widget-${DEVICE}.prg"
        else
            echo "ERROR: No compiled widget binary found for device '$DEVICE' at '$SELECTED_PRG'."
            echo "Ensure it is compiled under bin/."
            stop_simulator
            exit 1
        fi
    fi

    trap 'echo ""; stop_simulator; exit 130' SIGINT

    echo ">>> Running $SELECTED_PRG on simulator device '$DEVICE'..."
    echo "(Press Ctrl+C to stop the simulation and return here)"
    trap '' SIGINT
    monkeydo "$SELECTED_PRG" "$DEVICE" || true
    trap 'echo ""; stop_simulator; exit 130' SIGINT

    ask_pass_fail "$SELECTED_PRG" || true
    stop_simulator
fi
