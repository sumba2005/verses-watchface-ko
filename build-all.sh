#!/bin/bash
# Build PRGs for all devices declared in the manifest(s).
#
# Usage:
#   ./build-all.sh [developer_key_path]
#
# If no key given, falls back to ./developer_key (common in this repo).
# Builds both the Korean watchface (monkey.jungle) and widget (widget-kor.jungle)
# for every <iq:product> listed in the manifests.
#
# Output: bin/verses-kor-<product>.prg   and   bin/verses-widget-kor-<product>.prg
#
# After building you can use Garmin Express / BaseCamp / Connect Mobile
# or the tools/sideload.sh script.

set -e

KEY="${1:-developer_key}"
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

echo "Using monkeyc: $MONKEYC"
echo "Using key     : $KEY"
echo ""

mkdir -p bin

# Extract product ids from the manifests
WF_PRODUCTS=$(grep -o '<iq:product[^>]*id="[^"]*"' manifest-kor.xml | grep -o 'id="[^"]*"' | sed 's/id="//;s/"//' | tr '\n' ' ')
WD_PRODUCTS=$(grep -o '<iq:product[^>]*id="[^"]*"' manifest-widget-kor.xml | grep -o 'id="[^"]*"' | sed 's/id="//;s/"//' | tr '\n' ' ')

if [ -z "$WF_PRODUCTS" ] && [ -z "$WD_PRODUCTS" ]; then
    echo "ERROR: could not parse any <iq:product> from manifests"
    exit 1
fi

echo "Watchface devices:"
for d in $WF_PRODUCTS; do echo "  - $d"; done
echo ""
echo "Widget devices:"
for d in $WD_PRODUCTS; do echo "  - $d"; done
echo ""

FAILED=""
SUCCEEDED=""

build_one() {
    local kind="$1"      # face or widget
    local jungle="$2"
    local manifest="$3"
    local prefix="$4"    # verses-kor or verses-widget-kor
    local dev="$5"

    local out="bin/${prefix}-${dev}.prg"
    echo ">>> Building $kind for $dev -> $out"

    if $MONKEYC -f "$jungle" -d "$dev" -o "$out" -w -y "$KEY"; then
        echo "    ✅ $out"
        SUCCEEDED="$SUCCEEDED $out"
    else
        echo "    ❌ FAILED for $dev"
        FAILED="$FAILED $dev($kind)"
    fi
    echo ""
}

echo "=== Building Watchfaces ==="
for dev in $WF_PRODUCTS; do
    build_one "watchface" "monkey.jungle" "manifest-kor.xml" "verses-kor" "$dev"
done

echo "=== Building Widgets ==="
for dev in $WD_PRODUCTS; do
    build_one "widget"    "widget-kor.jungle" "manifest-widget-kor.xml" "verses-widget-kor" "$dev"
done

# Convenience aliases for the most common device
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
echo "Succeeded:${SUCCEEDED}"
if [ -n "$FAILED" ]; then
    echo "Failed:   ${FAILED}"
    exit 1
fi
echo "All PRGs are in bin/ ready for sideloading."
echo ""
echo "Tip: ./tools/sideload.sh kor   (auto-detects connected watch and picks best .prg)"
