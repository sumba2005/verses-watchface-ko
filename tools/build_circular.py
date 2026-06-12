#!/usr/bin/env python3
import os
import sys
import glob
import json
import xml.etree.ElementTree as ET
import subprocess
import argparse

def find_sdk_bin():
    """Auto-detect the Connect IQ SDK path under ~/.Garmin/ConnectIQ/Sdks/"""
    sdk_dirs = glob.glob(os.path.expanduser("~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-*"))
    if sdk_dirs:
        sdk_dirs.sort()  # Latest version will be last
        latest_sdk = sdk_dirs[-1]
        bin_dir = os.path.join(latest_sdk, "bin")
        if os.path.isdir(bin_dir):
            return bin_dir
    return ""

def get_devices_from_manifest(manifest_path):
    """Parse manifest-kor.xml to get the list of supported products"""
    try:
        tree = ET.parse(manifest_path)
        root = tree.getroot()
        ns = {'iq': 'http://www.garmin.com/xml/connectiq'}
        products = []
        for product in root.findall('.//iq:product', ns):
            product_id = product.get('id')
            if product_id:
                products.append(product_id)
        return products
    except Exception as e:
        print(f"Error parsing manifest {manifest_path}: {e}")
        return []

def get_device_info(device_id):
    """Read compiler.json for device to get shape and API level"""
    device_dir = os.path.expanduser(f"~/.Garmin/ConnectIQ/Devices/{device_id}")
    compiler_json_path = os.path.join(device_dir, "compiler.json")
    if not os.path.isfile(compiler_json_path):
        return None
    try:
        with open(compiler_json_path, 'r') as f:
            data = json.load(f)
            family = data.get("deviceFamily", "")
            group = data.get("deviceGroup", "")
            
            is_circular = "round" in family.lower()
            api_level = group.replace("API level ", "").strip()
            
            return {
                "is_circular": is_circular,
                "api_level": api_level
            }
    except Exception as e:
        print(f"Error reading compiler.json for {device_id}: {e}")
        return None

def build_device(sdk_bin, device_id, proj_root):
    """Build the watch face for the specified device"""
    monkeyc = os.path.join(sdk_bin, "monkeyc")
    output_prg = os.path.join(proj_root, "bin", f"verses-kor-{device_id}.prg")
    jungle = os.path.join(proj_root, "monkey.jungle")
    key = os.path.join(proj_root, "developer_key")
    
    cmd = [
        monkeyc,
        "-f", jungle,
        "-d", device_id,
        "-o", output_prg,
        "-y", key,
        "-w"
    ]
    
    print(f"\nBuilding watch face for {device_id}...")
    
    try:
        res = subprocess.run(cmd, cwd=proj_root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print(res.stdout)
        if res.stderr:
            print(res.stderr, file=sys.stderr)
        if res.returncode == 0:
            print(f"✅ Build successful: {output_prg}")
            return True
        else:
            print(f"❌ Build failed for {device_id} with exit code {res.returncode}")
            return False
    except Exception as e:
        print(f"Error executing compiler for {device_id}: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Build Garmin watchface for circular devices.")
    parser.add_argument("--api", nargs="+", help="Filter by API levels (e.g., 5.0 5.2 6.0)")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    proj_root = os.path.dirname(script_dir)
    
    sdk_bin = find_sdk_bin()
    if not sdk_bin:
        print("Error: Could not find Connect IQ SDK under ~/.Garmin/ConnectIQ/Sdks/", file=sys.stderr)
        sys.exit(1)
    print(f"Found SDK Bin: {sdk_bin}")

    manifest_path = os.path.join(proj_root, "manifest-kor.xml")
    if not os.path.isfile(manifest_path):
        print(f"Error: Manifest not found at {manifest_path}", file=sys.stderr)
        sys.exit(1)
        
    devices = get_devices_from_manifest(manifest_path)
    if not devices:
        print("Error: No devices found in manifest", file=sys.stderr)
        sys.exit(1)
        
    target_devices = []
    skipped_devices = []
    
    for dev in devices:
        info = get_device_info(dev)
        if not info:
            continue
        if info["is_circular"]:
            if args.api:
                if info["api_level"] in args.api:
                    target_devices.append((dev, info["api_level"]))
                else:
                    skipped_devices.append((dev, info["api_level"]))
            else:
                target_devices.append((dev, info["api_level"]))
                
    if args.api:
        print(f"Filtering by API levels: {', '.join(args.api)}")
        print(f"Skipped {len(skipped_devices)} circular watches with other API levels: "
              f"{', '.join([f'{d[0]} ({d[1]})' for d in skipped_devices])}")
              
    print(f"Circular devices to build ({len(target_devices)}): "
          f"{', '.join([f'{d[0]} ({d[1]})' for d in target_devices])}")
          
    if not target_devices:
        print("No matching devices to build.")
        sys.exit(0)
        
    os.makedirs(os.path.join(proj_root, "bin"), exist_ok=True)
    
    success_count = 0
    for device, _ in target_devices:
        if build_device(sdk_bin, device, proj_root):
            success_count += 1
            
    print(f"\nSummary: Successfully built {success_count}/{len(target_devices)} circular watches.")
    if success_count < len(target_devices):
        sys.exit(1)

if __name__ == "__main__":
    main()
