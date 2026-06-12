#!/bin/bash
# Build script for Verses watchface with pagination

set -e

MONKEYC=$(which monkeyc 2>/dev/null || echo "")

if [ -z "$MONKEYC" ]; then
    echo "ERROR: monkeyc not found in PATH"
    echo ""
    echo "Install Connect IQ SDK: https://developer.garmin.com/downloads/connect-iq/"
    echo ""
    echo "Then try again or set MONKEYC environment variable:"
    echo "  export MONKEYC=/path/to/connectiq/bin/monkeyc"
    exit 1
fi

echo "Building Verses watchface with pagination..."
echo "monkeyc: $MONKEYC"
echo ""

# Ensure bin directory exists
mkdir -p bin


# Build Korean version (quick single-device for the common vivoactive4 target)
echo "Building Korean version (verses-kor-vivoactive4.prg)..."
$MONKEYC -f monkey.jungle -d vivoactive4 -o bin/verses-kor-vivoactive4.prg -w -y developer_key || {
    echo "Build failed. Check for errors above."
    exit 1
}
cp -f bin/verses-kor-vivoactive4.prg bin/verses-kor.prg

echo "✅ Korean build complete: bin/verses-kor-vivoactive4.prg (alias: bin/verses-kor.prg)"
echo ""
echo "To build .prg files for *all* supported Garmin watches (30+ devices):"
echo "  ./build-all.sh developer_key"
echo "  (devices come from <iq:products> in manifest-kor.xml + manifest-widget-kor.xml)"
echo ""
echo "======================================"
echo "Build successful! Ready to sideload."
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Connect your Garmin watch via USB"
echo "2. See SIDELOAD.md or run: ./tools/sideload.sh kor"
echo ""
