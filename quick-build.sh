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
if ! command -v monkeyc &> /dev/null; then
    echo "ERROR: monkeyc not found in PATH"
    echo "Install Connect IQ SDK: https://developer.garmin.com/downloads/connect-iq/"
    exit 1
fi

mkdir -p bin

echo "Building Korean version (vivoactive4 default)..."
monkeyc -f monkey.jungle -d vivoactive4 -o bin/verses-kor-vivoactive4.prg -y "$KEY_PATH" -w && \
cp -f bin/verses-kor-vivoactive4.prg bin/verses-kor.prg && \
echo "✅ Korean Watchface: bin/verses-kor-vivoactive4.prg (alias: bin/verses-kor.prg)"

echo ""
echo "Building Korean Widget..."
monkeyc -f widget-kor.jungle -d vivoactive4 -o bin/verses-widget-kor-vivoactive4.prg -y "$KEY_PATH" -w && \
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
