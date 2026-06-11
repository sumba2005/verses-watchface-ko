#!/bin/bash
# Connect IQ Simulator Runner
# Usage: 
#   ./run-simulator.sh                 (interactive menu)
#   ./run-simulator.sh [device]        (run watchface or widget)
#   ./run-simulator.sh [device] [type] (specify face or widget)

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

# 3. Determine which .prg to run
SELECTED_PRG=""
DEVICE=""

if [ $# -eq 0 ]; then
    # Interactive menu mode
    all_prg_files=(bin/*.prg)
    if [ ${#all_prg_files[@]} -eq 0 ] || [ ! -e "${all_prg_files[0]}" ]; then
        echo "ERROR: No compiled .prg files found in bin/."
        echo "Run ./build.sh or ./build-all.sh first."
        exit 1
    fi

    prg_files=()
    for f in "${all_prg_files[@]}"; do
        name=$(basename "$f" .prg)
        if [ -f failed_target.txt ] && grep -qxF "$name" failed_target.txt; then
            continue
        fi
        prg_files+=("$f")
    done

    if [ ${#prg_files[@]} -eq 0 ]; then
        echo "ERROR: All targets are marked as failed in failed_target.txt."
        exit 1
    fi

    echo "Select a target to run in the simulator:"
    # Use select for a simple CLI menu
    PS3="Enter selection number: "
    select file in "${prg_files[@]}"; do
        if [ -n "$file" ]; then
            SELECTED_PRG="$file"
            break
        else
            echo "Invalid selection."
        fi
    done

    # Extract device from file name
    filename=$(basename "$SELECTED_PRG" .prg)
    if [[ "$filename" =~ ^verses-widget-kor-(.+)$ ]]; then
        DEVICE="${BASH_REMATCH[1]}"
    elif [[ "$filename" =~ ^verses-kor-(.+)$ ]]; then
        DEVICE="${BASH_REMATCH[1]}"
    elif [ "$filename" = "verses-kor" ]; then
        DEVICE="vivoactive4"
    elif [ "$filename" = "verses-widget-kor" ]; then
        DEVICE="vivoactive4"
    else
        DEVICE=${filename##*-}
    fi
else
    # Argument mode
    DEVICE="$1"
    TYPE="${2:-}"
    
    if [ -n "$TYPE" ]; then
        TYPE=$(echo "$TYPE" | tr '[:upper:]' '[:lower:]')
    fi

    # Determine candidates
    candidates=()
    if [ "$TYPE" = "widget" ]; then
        candidates+=( "bin/verses-widget-kor-${DEVICE}.prg" )
    elif [ "$TYPE" = "face" ] || [ "$TYPE" = "watchface" ]; then
        candidates+=( "bin/verses-kor-${DEVICE}.prg" )
    else
        # Try watchface first, then widget
        candidates+=( "bin/verses-kor-${DEVICE}.prg" "bin/verses-widget-kor-${DEVICE}.prg" )
    fi

    for cand in "${candidates[@]}"; do
        if [ -f "$cand" ]; then
            SELECTED_PRG="$cand"
            break
        fi
    done

    if [ -z "$SELECTED_PRG" ]; then
        echo "ERROR: No compiled binary found for device '$DEVICE' (type: ${TYPE:-any})."
        echo "Ensure it is spelled correctly and compiled under bin/."
        exit 1
    fi
fi

stop_simulator() {
    if [ "$SIMULATOR_STARTED" -eq 1 ]; then
        echo "Stopping Connect IQ Simulator..."
        pkill -x "simulator" 2>/dev/null || true
        pkill -f "connectiq" 2>/dev/null || true
        SIMULATOR_STARTED=0
    fi
}

ask_pass_fail() {
    trap - SIGINT
    stop_simulator
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
            p|pass) echo "Result: PASS"; break ;;
            f|fail)
                echo "Result: FAIL"
                local target_name
                target_name=$(basename "$SELECTED_PRG" .prg)
                echo "$target_name" >> failed_target.txt
                echo "Recorded '$target_name' in failed_target.txt"
                break ;;
            *) echo "Please enter p (pass) or f (fail)." ;;
        esac
    done
    echo "======================================"
}

trap ask_pass_fail SIGINT

# 4. Launch the binary
echo ">>> Running $SELECTED_PRG on simulator device '$DEVICE'..."
monkeydo "$SELECTED_PRG" "$DEVICE"

ask_pass_fail

