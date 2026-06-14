#!/bin/bash
# Build a Connect IQ Store package (.iq) for the Korean widget.
#
# Usage:
#   ./build-widget-iq.sh [developer_key_path]
#
# Output: bin/verses-widget-kor-<version>.iq  — upload this file to the Connect IQ Store.
#

set -e

KEY="${1:-developer_key}"
if [ ! -f "$KEY" ]; then
    echo "ERROR: developer key not found: $KEY"
    echo "Pass it as first arg or place a 'developer_key' file in the project root."
    exit 1
fi

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

VERSION=$(python3 -c "import xml.etree.ElementTree as ET; ns={'iq':'http://www.garmin.com/xml/connectiq'}; print(ET.parse('manifest-widget-kor.xml').find('iq:application',ns).get('version'))")
OUT="bin/verses-widget-kor-${VERSION}.iq"

echo "Using monkeyc : $MONKEYC"
echo "Using key     : $KEY"
echo "Widget version: $VERSION"
echo "Output        : $OUT"
echo ""

mkdir -p bin

echo "Building Widget IQ package for all devices in manifest-widget-kor.xml..."
$MONKEYC -f widget-kor.jungle --package-app -o "$OUT" -y "$KEY" -w

echo ""
echo "✅ Widget IQ package built: $OUT"
echo ""
echo "Upload $OUT to the Connect IQ Store:"
echo "  https://apps.garmin.com/developer/apps"
