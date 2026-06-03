#!/usr/bin/env python3
"""Generate a Connect IQ bitmap font (BMFont .fnt + .png) for exactly the glyphs
the verses use. No external font tool needed — uses PIL/FreeType.

  TTF/TTC source : Noto Sans CJK (Korean glyphs)
  glyph set      : tools/glyphs.txt (produced by build_resources.py)
  output         : resources/fonts/verse.fnt + resources/fonts/verse.png

Usage:  python3 tools/make_bmfont.py [SIZE]   (default SIZE=30)
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TTF  = os.environ.get("TTF", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")
SIZE = int(sys.argv[1]) if len(sys.argv) > 1 else 30
PAD  = 1
ATLAS_W = 512

def main():
    glyph_txt = os.path.join(ROOT, "tools", "glyphs.txt")
    chars = list(dict.fromkeys(open(glyph_txt, encoding="utf-8").read()))
    chars = [c for c in chars if c not in ("\n", "\r")]
    if " " not in chars:
        chars.append(" ")

    font = ImageFont.truetype(TTF, SIZE, index=0)
    ascent, descent = font.getmetrics()
    line_height = ascent + descent

    # Render each glyph to a tight RGBA tile (white, alpha = coverage).
    tiles = []  # (char, img, w, h, xoffset, yoffset, xadvance)
    for ch in chars:
        xadv = round(font.getlength(ch))
        bbox = font.getbbox(ch)  # anchor 'la': (x0,y0,x1,y1) from left/ascender-top
        if bbox is None or (bbox[2] - bbox[0]) <= 0 or (bbox[3] - bbox[1]) <= 0:
            tiles.append((ch, None, 0, 0, 0, 0, xadv))
            continue
        x0, y0, x1, y1 = bbox
        gw, gh = x1 - x0, y1 - y0
        gi = Image.new("RGBA", (gw, gh), (0, 0, 0, 0))
        ImageDraw.Draw(gi).text((-x0, -y0), ch, font=font, fill=(255, 255, 255, 255))
        tiles.append((ch, gi, gw, gh, x0, y0, xadv))

    # Shelf-pack into an ATLAS_W-wide atlas.
    x = y = 0
    row_h = 0
    placements = []  # (char, ax, ay, w, h, xoffset, yoffset, xadvance)
    for ch, gi, gw, gh, xo, yo, xadv in tiles:
        if gi is None:
            placements.append((ch, 0, 0, 0, 0, 0, 0, xadv))
            continue
        if x + gw + PAD > ATLAS_W:
            x = 0
            y += row_h + PAD
            row_h = 0
        placements.append((ch, x, y, gw, gh, xo, yo, xadv))
        x += gw + PAD
        row_h = max(row_h, gh)
    atlas_h = ((y + row_h + 3) // 4) * 4  # round up to /4

    atlas = Image.new("RGBA", (ATLAS_W, atlas_h), (0, 0, 0, 0))
    for (ch, ax, ay, w, h, xo, yo, xadv), (_, gi, *_rest) in zip(placements, tiles):
        if gi is not None:
            atlas.paste(gi, (ax, ay))

    out_dir = os.environ.get("OUTDIR", os.path.join(ROOT, "resources", "fonts"))
    if not os.path.isabs(out_dir):
        out_dir = os.path.join(ROOT, out_dir)
    os.makedirs(out_dir, exist_ok=True)
    png_name = "verse.png"
    atlas.save(os.path.join(out_dir, png_name))

    # Emit BMFont text descriptor.
    lines = []
    lines.append(f'info face="NotoSansCJK" size={SIZE} bold=0 italic=0 charset="" '
                 f'unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0')
    lines.append(f'common lineHeight={line_height} base={ascent} scaleW={ATLAS_W} '
                 f'scaleH={atlas_h} pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0')
    lines.append(f'page id=0 file="{png_name}"')
    lines.append(f'chars count={len(placements)}')
    for ch, ax, ay, w, h, xo, yo, xadv in placements:
        lines.append(f'char id={ord(ch)} x={ax} y={ay} width={w} height={h} '
                     f'xoffset={xo} yoffset={yo} xadvance={xadv} page=0 chnl=15')
    lines.append('kernings count=0')
    with open(os.path.join(out_dir, "verse.fnt"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"size={SIZE} lineHeight={line_height} base={ascent}")
    print(f"glyphs={len(placements)}  atlas={ATLAS_W}x{atlas_h}")
    print(f"wrote {os.path.relpath(out_dir, ROOT)}/verse.fnt + verse.png "
          f"({os.path.getsize(os.path.join(out_dir, png_name))} bytes)")

if __name__ == "__main__":
    main()
