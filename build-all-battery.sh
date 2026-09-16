#!/bin/bash
set -e
echo "=== Building Battery Saver for ALL watch models ==="
KEY="${1:-developer_key}"
MONKEYC=$(which monkeyc 2>/dev/null || echo "/home/jkim/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-9.2.0-2026-06-09-92a1605b2/bin/monkeyc")
mkdir -p bin

if [ ! -f "$KEY" ]; then
  echo "Using key: $KEY (make sure it exists)"
fi

# Extract all product ids from manifest (avoid app id)
PRODUCTS=$(grep '<iq:product id=' manifest-battery-saver.xml | sed 's/.*id="//;s/".*//' | tr '\n' ' ')

echo "Found products: $PRODUCTS"
echo "Building for each (this may take several minutes)..."

for device in $PRODUCTS; do
  echo "Building for $device..."
  "$MONKEYC" -f battery-saver.jungle -d "$device" -o "bin/battery-saver-$device.prg" -y "$KEY" -w || echo "Warning: build failed for $device (check failed_target.txt)"
done

echo "All builds completed. PRGs in bin/battery-saver-*.prg"
echo "Use ./sideload-battery-saver.sh or Garmin BaseCamp for deployment."
ls -lh bin/battery-saver-*.prg | head -5
