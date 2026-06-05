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

# Build English version
echo "Building English version (verses-face-4s.prg)..."
$MONKEYC -f eng.jungle -o bin/verses-face-4s.prg -l || {
    echo "Build failed. Check for errors above."
    exit 1
}

echo "✅ English build complete: bin/verses-face-4s.prg"
echo ""

# Build Korean version
echo "Building Korean version (verses-kor-4s.prg)..."
$MONKEYC -f monkey.jungle -o bin/verses-kor-4s.prg -l || {
    echo "Build failed. Check for errors above."
    exit 1
}

echo "✅ Korean build complete: bin/verses-kor-4s.prg"
echo ""
echo "======================================"
echo "Build successful! Ready to sideload."
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Connect vivoactive4/4s via USB"
echo "2. See SIDELOAD.md for installation options"
echo ""
