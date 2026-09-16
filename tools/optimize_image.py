#!/usr/bin/env python3
import os
import sys
import argparse
from PIL import Image

def optimize_png(file_path, target_kb=145):
    if not os.path.exists(file_path):
        print(f"Error: File not found {file_path}")
        return False
        
    initial_size = os.path.getsize(file_path) / 1024.0
    print(f"Optimizing {file_path} (Initial size: {initial_size:.1f} KB)...")
    
    img = Image.open(file_path)
    
    # Try standard optimization first
    img.save(file_path, "PNG", optimize=True)
    size_kb = os.path.getsize(file_path) / 1024.0
    if size_kb <= target_kb:
        print(f"✅ Success: Optimized to {size_kb:.1f} KB (under {target_kb} KB)")
        return True
        
    # If still too large, convert to 8-bit adaptive palette (reduces file size drastically)
    print(f"Still too large ({size_kb:.1f} KB). Quantizing to 8-bit palette...")
    
    # For RGBA, we want to maintain the transparency alpha mask cleanly
    if img.mode == "RGBA":
        # Create a quantized version with transparency preserved
        alpha = img.split()[3]
        # Quantize RGB part
        rgb_img = img.convert("RGB")
        quantized = rgb_img.quantize(colors=255, method=Image.Resampling.LANCZOS)
        
        # Add transparency back to the palette
        result = quantized.convert("RGBA")
        # Put alpha back
        result.putalpha(alpha)
        
        # Save as optimized PNG (P mode with transparency or optimized RGBA)
        # Modern Pillow can save quantized palette images with transparency
        quantized_trans = img.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
        quantized_trans.save(file_path, "PNG", optimize=True)
    else:
        # Simple palette conversion
        quantized = img.convert("P", palette=Image.Palette.ADAPTIVE, colors=256)
        quantized.save(file_path, "PNG", optimize=True)
        
    size_kb = os.path.getsize(file_path) / 1024.0
    if size_kb <= target_kb:
        print(f"✅ Success: Quantized to {size_kb:.1f} KB (under {target_kb} KB)")
        return True
    else:
        # If still too large, slightly downscale or reduce palette colors further
        print(f"Warning: Size is {size_kb:.1f} KB. Reducing colors to 128...")
        quantized = img.convert("P", palette=Image.Palette.ADAPTIVE, colors=128)
        quantized.save(file_path, "PNG", optimize=True)
        size_kb = os.path.getsize(file_path) / 1024.0
        print(f"Final color-reduced size: {size_kb:.1f} KB")
        return size_kb <= target_kb

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Optimize PNG file size to be under a target KB limit.")
    parser.add_argument("file", help="Path to the PNG file to optimize")
    parser.add_argument("--target", type=float, default=145.0, help="Target maximum size in KB (default: 145.0)")
    
    args = parser.parse_args()
    optimize_png(args.file, args.target)
