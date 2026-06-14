#!/bin/bash
# Build PRGs for all devices declared in the manifest(s) — with parallel job support.
#
# Usage:
#   ./build-all.sh [developer_key_path] [parallel_jobs]
#
# If no key given, falls back to ./developer_key (common in this repo).
# parallel_jobs defaults to 4 (can be any positive number or 0 for unlimited).
# Builds both the Korean watchface (monkey.jungle) and widget (widget-kor.jungle)
# for every <iq:product> listed in the manifests.
#
# Output: bin/verses-kor-<product>.prg   and   bin/verses-widget-kor-<product>.prg

set -e

KEY="${1:-developer_key}"
PARALLEL_JOBS="${2:-4}"

if [ ! -f "$KEY" ]; then
    echo "ERROR: developer key not found: $KEY"
    echo "Pass it as first arg or place a 'developer_key' file in the project root."
    exit 1
fi

MONKEYC=$(which monkeyc 2>/dev/null || echo "")
if [ -z "$MONKEYC" ]; then
    # Try the location used in run_build_and_sideload.sh
    for cand in \
        "$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc" \
        "$HOME/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.1.0-2026-03-09-6a872a80b/bin/monkeyc" \
        "/home/jkim/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc"
    do
        if [ -x "$cand" ]; then MONKEYC="$cand"; break; fi
    done
fi

if [ -z "$MONKEYC" ] || [ ! -x "$MONKEYC" ]; then
    echo "ERROR: monkeyc not found. Install Connect IQ SDK or put it on PATH."
    exit 1
fi

echo "Using monkeyc    : $MONKEYC"
echo "Using key        : $KEY"
echo "Parallel jobs    : $PARALLEL_JOBS"
echo ""

mkdir -p bin

# Extract product ids from the manifests
if [ ! -f manifest-kor.xml ] || [ ! -f manifest-widget-kor.xml ]; then
    echo "ERROR: manifest files not found"
    exit 1
fi

WF_PRODUCTS=$(grep -o '<iq:product[^>]*id="[^"]*"' manifest-kor.xml | grep -o 'id="[^"]*"' | sed 's/id="//;s/"//' | tr '\n' ' ')
WD_PRODUCTS=$(grep -o '<iq:product[^>]*id="[^"]*"' manifest-widget-kor.xml | grep -o 'id="[^"]*"' | sed 's/id="//;s/"//' | tr '\n' ' ')

if [ -z "$WF_PRODUCTS" ] && [ -z "$WD_PRODUCTS" ]; then
    echo "ERROR: could not parse any <iq:product> from manifests"
    exit 1
fi

echo "Watchface devices: $(echo $WF_PRODUCTS | wc -w)"
echo "Widget devices:    $(echo $WD_PRODUCTS | wc -w)"
echo ""

FAILED=""
SUCCEEDED=""
BUILD_LOG_DIR=$(mktemp -d)
trap "rm -rf $BUILD_LOG_DIR" EXIT

build_one() {
    local kind="$1"      # face or widget
    local jungle="$2"
    local prefix="$3"    # verses-kor or verses-widget-kor
    local dev="$4"

    local target="${prefix}-${dev}"
    if [ -f failed_target.txt ] && grep -qxF "$target" failed_target.txt; then
        echo "SKIP" > "$BUILD_LOG_DIR/${prefix}-${dev}.status"
        return 0
    fi

    local out="bin/${prefix}-${dev}.prg"
    local logfile="$BUILD_LOG_DIR/${prefix}-${dev}.log"

    if $MONKEYC -f "$jungle" -d "$dev" -o "$out" -w -y "$KEY" > "$logfile" 2>&1; then
        echo "OK" > "$BUILD_LOG_DIR/${prefix}-${dev}.status"
    else
        echo "FAIL" > "$BUILD_LOG_DIR/${prefix}-${dev}.status"
        cat "$logfile" >> "$BUILD_LOG_DIR/${prefix}-${dev}.error"
    fi
}

run_parallel_builds() {
    local kind="$1"      # face or widget
    local jungle="$2"
    local prefix="$3"    # verses-kor or verses-widget-kor
    local devices="$4"

    local total=$(echo "$devices" | wc -w)
    local completed=0
    echo "=== Building $kind ($total devices) ==="
    local job_count=0
    local pids=()
    local dev_list=($devices)

    for i in "${!dev_list[@]}"; do
        local dev="${dev_list[$i]}"
        local remaining=$((total - i - 1))

        # Wait if we've reached max parallel jobs
        if [ "$PARALLEL_JOBS" -gt 0 ] && [ $job_count -ge "$PARALLEL_JOBS" ]; then
            wait ${pids[0]}
            pids=("${pids[@]:1}")
            job_count=$((job_count - 1))
        fi

        # Launch build in background
        build_one "$kind" "$jungle" "$prefix" "$dev" &
        pids+=($!)
        job_count=$((job_count + 1))
        echo "  ⏳ $dev [$((i+1))/$total, $remaining left]"
    done

    # Wait for remaining jobs
    for pid in "${pids[@]}"; do
        wait $pid
    done

    # Report results
    local phase_succeeded=""
    local phase_failed=""
    for dev in $devices; do
        local status=$(cat "$BUILD_LOG_DIR/${prefix}-${dev}.status" 2>/dev/null || echo "UNKNOWN")
        case "$status" in
            OK)
                echo "    ✅ bin/${prefix}-${dev}.prg"
                phase_succeeded="$phase_succeeded bin/${prefix}-${dev}.prg"
                ;;
            FAIL)
                echo "    ❌ ${prefix}-${dev}"
                phase_failed="$phase_failed $dev($kind)"
                ;;
            SKIP)
                echo "    ⊘ ${prefix}-${dev} (skipped)"
                ;;
        esac
    done

    SUCCEEDED="$SUCCEEDED$phase_succeeded"
    FAILED="$FAILED$phase_failed"
}

run_parallel_builds "Watchface" "monkey.jungle" "verses-kor" "$WF_PRODUCTS"
echo ""
run_parallel_builds "Widget" "widget-kor.jungle" "verses-widget-kor" "$WD_PRODUCTS"

# Convenience aliases for the most common device
echo ""
if [ -f bin/verses-kor-vivoactive4.prg ]; then
    cp -f bin/verses-kor-vivoactive4.prg bin/verses-kor.prg
    echo "Created alias: bin/verses-kor.prg"
fi
if [ -f bin/verses-widget-kor-vivoactive4.prg ]; then
    cp -f bin/verses-widget-kor-vivoactive4.prg bin/verses-widget-kor.prg
    echo "Created alias: bin/verses-widget-kor.prg"
fi

echo ""
echo "========================================"
echo "Build run complete."
if [ -n "$SUCCEEDED" ]; then
    echo "Succeeded: $(echo $SUCCEEDED | wc -w) PRGs"
fi
if [ -n "$FAILED" ]; then
    echo "Failed:   $FAILED"
    exit 1
fi
echo "All PRGs are in bin/ ready for sideloading."
echo ""
echo "Tip: ./tools/sideload.sh kor   (auto-detects connected watch and picks best .prg)"
