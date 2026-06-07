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

echo "Building English version..."
monkeyc -f eng.jungle -d vivoactive4s -o bin/verses-face-4s.prg -y "$KEY_PATH" -w && \
echo "✅ English Watchface: bin/verses-face-4s.prg"

echo ""
echo "Building English Widget..."
monkeyc -f widget-eng.jungle -d vivoactive4s -o bin/verses-widget-eng.prg -y "$KEY_PATH" -w && \
echo "✅ English Widget: bin/verses-widget-eng.prg"

echo ""
echo "Building Korean version..."
monkeyc -f monkey.jungle -d vivoactive4s -o bin/verses-kor-4s.prg -y "$KEY_PATH" -w && \
echo "✅ Korean Watchface: bin/verses-kor-4s.prg"

echo ""
echo "Building Korean Widget..."
monkeyc -f widget-kor.jungle -d vivoactive4s -o bin/verses-widget-kor.prg -y "$KEY_PATH" -w && \
echo "✅ Korean Widget: bin/verses-widget-kor.prg"

echo ""
echo "=========================================="
echo "Build successful! Ready to sideload."
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Connect vivoactive4/4s via USB"
echo "2. Use Garmin BaseCamp to import bin/verses-face-4s.prg"
echo "   OR manually copy to: GARMIN/APPS/3f4362d960df42419ab01640cdf6788c/"
echo ""
echo "Testing on watch:"
echo "- Hold UP to view watch faces"
echo "- Select 'Verses' and activate"
echo "- TAP THE VERSE TEXT to test pagination"
echo ""
