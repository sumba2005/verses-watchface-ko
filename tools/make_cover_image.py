#!/usr/bin/env python3
import os
import sys
import argparse
from PIL import Image

def make_cover_image(img_path, output_path):
    print(f"Loading screenshot for cover image: {img_path}")
    img = Image.open(img_path).convert("RGBA")
    w, h = img.size
    
    # Garmin simulator screenshots are vertical (e.g., 595x858).
    # We want a 500x500 square centered on the smartwatch body.
    
    # 1. Determine background color from corners
    corners = [
        img.getpixel((0, 0)),
        img.getpixel((w - 1, 0)),
        img.getpixel((0, h - 1)),
        img.getpixel((w - 1, h - 1))
    ]
    bg_color = max(set(corners), key=corners.count)
    
    def is_bg(pixel):
        if pixel[3] < 10:
            return True
        dr = abs(pixel[0] - bg_color[0])
        dg = abs(pixel[1] - bg_color[1])
        db = abs(pixel[2] - bg_color[2])
        is_close_to_bg = (dr + dg + db) < 45
        is_near_white = (pixel[0] > 240 and pixel[1] > 240 and pixel[2] > 240)
        return is_close_to_bg or is_near_white

    # 2. Find the bounding box of the watch body to locate its center
    min_x, max_x = w, 0
    min_y, max_y = h, 0
    for y in range(h):
        for x in range(w):
            if not is_bg(img.getpixel((x, y))):
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                
    if max_x <= min_x or max_y <= min_y:
        # Fallback to absolute center
        cx, cy = w // 2, h // 2
    else:
        cx = (min_x + max_x) // 2
        cy = (min_y + max_y) // 2

    # 3. Crop a square centered at (cx, cy)
    # The size of the square crop should be based on the watch width to make it fit nicely
    watch_w = max_x - min_x
    watch_h = max_y - min_y
    crop_size = int(max(watch_w, watch_h) * 1.05) # Add 5% padding
    
    # Clamp crop size to image dimensions
    crop_size = min(crop_size, w, h)
    
    left = max(0, cx - crop_size // 2)
    top = max(0, cy - crop_size // 2)
    right = min(w, left + crop_size)
    bottom = min(h, top + crop_size)
    
    # Adjust if hitting edges to keep it square
    actual_w = right - left
    actual_h = bottom - top
    square_size = min(actual_w, actual_h)
    
    left = cx - square_size // 2
    top = cy - square_size // 2
    right = left + square_size
    bottom = top + square_size
    
    cropped = img.crop((left, top, right, bottom))
    
    # Make background transparent
    data = cropped.getdata()
    new_data = []
    for item in data:
        if is_bg(item):
            new_data.append((0, 0, 0, 0)) # transparent background
        else:
            new_data.append(item)
            
    transparent_cropped = Image.new("RGBA", cropped.size)
    transparent_cropped.putdata(new_data)
    
    # 4. Resize to exactly 500x500
    final_img = transparent_cropped.resize((500, 500), Image.Resampling.LANCZOS)
    
    # Save the output
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    final_img.save(output_path, "PNG")
    print(f"✅ 500x500 Cover Image successfully generated and saved to: {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Create a 500x500 square cover image centered on the watch face.")
    parser.add_argument("input", help="Path to input screenshot (e.g. the 16:00 image)")
    parser.add_argument("output", help="Path to save the 500x500 cover image")
    
    args = parser.parse_args()
    make_cover_image(args.input, args.output)
