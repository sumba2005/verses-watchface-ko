#!/bin/bash
# Quick build script for Verses watchface with pagination
# Usage: ./quick-build.sh /path/to/your/developer-key.p12

set -e

if [ $# -eq 0 ]; then
    echo "Usage: ./quick-build.sh /path/to/developer-key.p12"
    echo ""
    echo "Developer key locations:"
    echo "  macOS: ~/Library/Preferences/Garmin/ConnectIQ/Certificates/"
    echo "  Linux: ~/.Garmin/ConnectIQ/Certificates/"
    echo "  Windows: %APPDATA%\\Garmin\\ConnectIQ\\Certificates\\"
    echo ""
    echo "Or download from: https://developer.garmin.com/"
    exit 1
fi

KEY_PATH="$1"

if [ ! -f "$KEY_PATH" ]; then
    echo "ERROR: Key file not found: $KEY_PATH"
    exit 1
fi

echo "Building Verses watchface with pagination..."
echo "Key: $KEY_PATH"
echo ""

# Verify monkeyc is available
MONKEYC=$(which monkeyc 2>/dev/null || echo "")
if [ -z "$MONKEYC" ]; then
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

mkdir -p bin

echo "Building Korean version (vivoactive4 default)..."
"$MONKEYC" -f monkey.jungle -d vivoactive4 -o bin/verses-kor-vivoactive4.prg -y "$KEY_PATH" -w && \
cp -f bin/verses-kor-vivoactive4.prg bin/verses-kor.prg && \
echo "✅ Korean Watchface: bin/verses-kor-vivoactive4.prg (alias: bin/verses-kor.prg)"

echo ""
echo "Building Korean Widget..."
"$MONKEYC" -f widget-kor.jungle -d vivoactive4 -o bin/verses-widget-kor-vivoactive4.prg -y "$KEY_PATH" -w && \
cp -f bin/verses-widget-kor-vivoactive4.prg bin/verses-widget-kor.prg && \
echo "✅ Korean Widget: bin/verses-widget-kor-vivoactive4.prg (alias: bin/verses-widget-kor.prg)"

echo ""
echo "For ALL supported devices (fenix, epix, venu*, fr*, vivoactive5, etc.):"
echo "  ./build-all.sh \"$KEY_PATH\""
echo "  (see build-all.sh and the <iq:products> in manifest-kor.xml)"

echo ""
echo "=========================================="
echo "Build successful! Ready to sideload."
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Connect watch via USB"
echo "2. Use Garmin BaseCamp to import bin/verses-kor.prg"
echo "   OR manually copy to: GARMIN/APPS/3f4362d960df42419ab01640cdf6788c/"
echo ""
echo "Testing on watch:"
echo "- Hold UP to view watch faces"
echo "- Select 'Verses' and activate"
echo "- TAP THE VERSE TEXT to test pagination"
echo ""
