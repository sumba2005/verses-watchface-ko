#!/usr/bin/env python3
import os
import sys
import glob
import time
import socket
import subprocess
import xml.etree.ElementTree as ET
import json
import argparse

SDK_BIN = ""

def find_sdk_bin():
    global SDK_BIN
    sdk_dirs = glob.glob(os.path.expanduser("~/.Garmin/ConnectIQ/Sdks/connectiq-sdk-lin-*"))
    if sdk_dirs:
        sdk_dirs.sort()  # Latest version will be last
        latest_sdk = sdk_dirs[-1]
        bin_dir = os.path.join(latest_sdk, "bin")
        if os.path.isdir(bin_dir):
            SDK_BIN = bin_dir
            return bin_dir
    return ""

def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1.0)
        try:
            s.connect(("127.0.0.1", port))
            return True
        except:
            return False

def get_devices_from_manifest(manifest_path):
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

def build_device_if_missing(device_id, proj_root):
    output_prg = os.path.join(proj_root, "bin", f"verses-kor-{device_id}.prg")
    if os.path.isfile(output_prg):
        return output_prg
        
    print(f"PRG for {device_id} is missing. Building it first...")
    monkeyc = os.path.join(SDK_BIN, "monkeyc")
    jungle = os.path.join(proj_root, "monkey.jungle")
    key = os.path.join(proj_root, "developer_key")
    cmd = [monkeyc, "-f", jungle, "-d", device_id, "-o", output_prg, "-y", key, "-w"]
    
    try:
        res = subprocess.run(cmd, cwd=proj_root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode == 0:
            print(f"✅ Built: {output_prg}")
            return output_prg
        else:
            print(f"❌ Failed to build for {device_id}")
            print(res.stderr)
            return None
    except Exception as e:
        print(f"Error building {device_id}: {e}")
        return None

def clean_do_processes():
    try:
        subprocess.run(["pkill", "-f", "monkeydo"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["pkill", "-f", "shell --transport=tcp"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def main():
    parser = argparse.ArgumentParser(description="Test Garmin watchfaces in simulator.")
    parser.add_argument("--api", nargs="+", help="Filter by API levels (e.g., 5.0 5.2 6.0)")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    proj_root = os.path.dirname(script_dir)
    
    sdk_bin = find_sdk_bin()
    if not sdk_bin:
        print("Error: Could not find Connect IQ SDK under ~/.Garmin/ConnectIQ/Sdks/", file=sys.stderr)
        sys.exit(1)
        
    manifest_path = os.path.join(proj_root, "manifest-kor.xml")
    if not os.path.isfile(manifest_path):
        print(f"Error: Manifest not found at {manifest_path}", file=sys.stderr)
        sys.exit(1)
        
    devices = get_devices_from_manifest(manifest_path)
    circular_devices = []
    
    for dev in devices:
        info = get_device_info(dev)
        if not info:
            continue
        if info["is_circular"]:
            if args.api:
                if info["api_level"] in args.api:
                    circular_devices.append(dev)
            else:
                circular_devices.append(dev)
                
    if not circular_devices:
        print("No matching circular devices found to test.")
        sys.exit(0)
        
    if args.api:
        print(f"Filtering simulator tests by API levels: {', '.join(args.api)}")
    print(f"Circular devices to test: {', '.join(circular_devices)}")
    
    prg_paths = {}
    for dev in circular_devices:
        path = build_device_if_missing(dev, proj_root)
        if path:
            prg_paths[dev] = path
            
    if not prg_paths:
        print("Error: No devices built. Exiting.")
        sys.exit(1)
        
    # Start simulator
    simulator_bin = os.path.join(sdk_bin, "simulator")
    print("Starting simulator...")
    sim_proc = subprocess.Popen([simulator_bin], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    
    # Wait for simulator port
    print("Waiting for simulator to listen on port 1234...")
    for _ in range(15):
        if is_port_open(1234):
            print("Simulator is ready.")
            break
        time.sleep(1)
    else:
        print("Error: Simulator failed to start listening on port 1234.")
        sim_proc.kill()
        sys.exit(1)
        
    monkeydo_bin = os.path.join(sdk_bin, "monkeydo")
    
    try:
        for i, device in enumerate(circular_devices):
            if device not in prg_paths:
                print(f"Skipping {device} (build failed).")
                continue
                
            prg_path = prg_paths[device]
            print(f"\n==========================================")
            print(f" [{i+1}/{len(circular_devices)}] Testing {device} ")
            print(f"==========================================")
            
            clean_do_processes()
            
            print(f"Launching {device} watch face in simulator...")
            do_proc = subprocess.Popen([monkeydo_bin, prg_path, device], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            time.sleep(2) # Give it a moment to render
            
            try:
                input(f"👉 Now showing {device} in simulator. Press Enter to proceed to next watch (or Ctrl+C to exit)...")
            except KeyboardInterrupt:
                print("\nExiting testing session.")
                break
                
            do_proc.kill()
            
    finally:
        print("\nCleaning up simulator processes...")
        clean_do_processes()
        sim_proc.kill()
        subprocess.run(["pkill", "-f", "simulator"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print("Done.")

if __name__ == "__main__":
    main()
