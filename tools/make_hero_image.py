#!/usr/bin/env python3
import os
import sys
import argparse
from PIL import Image

def make_hero_image(img_left_path, img_center_path, img_right_path, output_path):
    print(f"Loading screenshots:\n  Left: {img_left_path}\n  Center: {img_center_path}\n  Right: {img_right_path}")
    
    img_left = Image.open(img_left_path).convert("RGBA")
    img_center = Image.open(img_center_path).convert("RGBA")
    img_right = Image.open(img_right_path).convert("RGBA")
    
    canvas_w = 1440
    canvas_h = 720
    canvas = Image.new("RGBA", (canvas_w, canvas_h))
    
    each_w = 480
    each_h = 720
    
    images = [img_left, img_center, img_right]
    offsets_x = [0, 480, 960]
    
    print("Resizing and cropping screenshots to fit horizontally...")
    for img, offset_x in zip(images, offsets_x):
        w, h = img.size
        # Scale image to match height of 720px
        scale = each_h / h
        new_w = int(w * scale)
        new_h = each_h
        
        resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Center crop (or pad) horizontally to exactly 480px width
        if new_w >= each_w:
            left_crop = (new_w - each_w) // 2
            cropped = resized.crop((left_crop, 0, left_crop + each_w, each_h))
        else:
            # If resized width is narrower than 480px, pad with the corner color of the image
            bg_color = resized.getpixel((0, 0))
            cropped = Image.new("RGBA", (each_w, each_h), bg_color)
            left_paste = (each_w - new_w) // 2
            cropped.paste(resized, (left_paste, 0))
            
        canvas.paste(cropped, (offset_x, 0))
        
    # Save output
    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
    canvas.convert("RGB").save(output_path, "PNG")
    print(f"✅ Simple horizontal collage successfully generated at: {output_path}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Combine three Garmin watch screenshots side-by-side horizontally into a 1440x720 store marketing hero banner.")
    parser.add_argument("left", help="Path to left screenshot")
    parser.add_argument("center", help="Path to center screenshot")
    parser.add_argument("right", help="Path to right screenshot")
    parser.add_argument("output", help="Path where the final 1440x720 PNG should be saved")
    
    args = parser.parse_args()
    make_hero_image(args.left, args.center, args.right, args.output)
