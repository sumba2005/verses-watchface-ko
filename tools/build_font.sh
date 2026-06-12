#!/usr/bin/env bash
# Build the embedded per-language bitmap font for the watch face.
#
#   ./tools/build_font.sh [lang]      (default: kor)
#
# We embed our OWN font subset to ONLY the glyphs that language's verses actually
# use, so text renders regardless of device font support while staying tiny.
# A Korean build carries ~247 Hangul glyphs; an English build only ~60 Latin
# glyphs (much smaller). vivoactive4's watchFace budget is 512 KB, comfortable.
#
# Pick the TTF per language (override with TTF=...):
#   - Korean : Noto Sans KR  (OFL): https://fonts.google.com/noto/specimen/Noto+Sans+KR
#   - English: any Latin TTF, e.g. Noto Sans / Roboto (OFL/Apache)
# Other prereqs (install once):
#   - fontbm (BMFont generator): https://github.com/vladimirgamalyan/fontbm
#   - (optional) fonttools:  pip install fonttools   # to pre-subset the TTF
#
# Connect IQ custom fonts are BMFont format: a .fnt descriptor + a .png texture.
set -euo pipefail
cd "$(dirname "$0")/.."

LANG="${1:-kor}"                              # language code: matches verses-<lang>.csv / resources-<lang>/
# Sensible default TTF per language; override with TTF=/path/to.ttf
DEFAULT_TTF="tools/NotoSansKR-Regular.otf"
TTF="${TTF:-$DEFAULT_TTF}"
SIZE="${SIZE:-20}"                            # point size; tune so all verses fit one screen
GLYPHS="tools/glyphs-$LANG.txt"
OUT_DIR="${OUT_DIR:-resources_${LANG}/fonts}"
OUT="$OUT_DIR/verse"

[ -f "$GLYPHS" ] || { echo "Missing $GLYPHS — run: python3 tools/build_resources.py $LANG"; exit 1; }
[ -f "$TTF" ]    || { echo "Missing font TTF at $TTF (set TTF=/path/to.ttf)"; exit 1; }
FONTBM="fontbm"
if [ -f "tools/fontbm" ]; then
    FONTBM="tools/fontbm"
elif command -v fontbm >/dev/null; then
    FONTBM="fontbm"
else
    echo "fontbm not found — see header for install link"
    exit 1
fi

mkdir -p "$OUT_DIR"

# Determine size for reference font
if [ "$SIZE" -eq 12 ]; then
    REF_SIZE="${REF_SIZE:-12}"
elif [ "$SIZE" -ge 28 ]; then
    # Large fonts (e.g. 30pt for high-res watches) often need bigger texture or multiple pages.
    REF_SIZE="${REF_SIZE:-25}"
else
    REF_SIZE="${REF_SIZE:-17}"
fi

TEXTURE_SIZE="${TEXTURE_SIZE:-512x512}"
if [ "$SIZE" -ge 28 ]; then
    TEXTURE_SIZE="${TEXTURE_SIZE:-1024x1024}"
fi

echo "Building verse font (size $SIZE, texture $TEXTURE_SIZE)..."
"$FONTBM" \
  --font-file "$TTF" \
  --font-size "$SIZE" \
  --chars-file "$GLYPHS" \
  --texture-size "$TEXTURE_SIZE" \
  --color 255,255,255 \
  --output "$OUT_DIR/verse"

# Handle single-page (verse_0.png → verse.png) or multi-page (leave verse.png + verse_1.png etc.)
if [ -f "${OUT_DIR}/verse_0.png" ] && [ ! -f "${OUT_DIR}/verse_1.png" ]; then
    mv "${OUT_DIR}/verse_0.png" "${OUT_DIR}/verse.png"
    sed -i 's/file="verse_0.png"/file="verse.png"/g' "${OUT_DIR}/verse.fnt"
fi

echo "Building reference font (size $REF_SIZE)..."
"$FONTBM" \
  --font-file "$TTF" \
  --font-size "$REF_SIZE" \
  --chars-file "$GLYPHS" \
  --texture-size "$TEXTURE_SIZE" \
  --color 255,255,255 \
  --output "$OUT_DIR/ref"

if [ -f "${OUT_DIR}/ref_0.png" ] && [ ! -f "${OUT_DIR}/ref_1.png" ]; then
    mv "${OUT_DIR}/ref_0.png" "${OUT_DIR}/ref.png"
    sed -i 's/file="ref_0.png"/file="ref.png"/g' "${OUT_DIR}/ref.fnt"
fi

echo "Generated $OUT.fnt + $OUT.png  (lang=$LANG)"
cat <<EOF

Next:
  1) Ensure resources-$LANG/fonts/fonts.xml exists:
       <resources>
         <font id="VerseFont" filename="verse.fnt"/>
       </resources>
  2) (4S only) for a smaller screen font, re-run with SIZE=12 and copy the
     output into resources-$LANG-vivoactive4s/fonts/ (device qualifier override).
  3) For high-resolution/large-screen watches (epix2, fenix7x, fr965, venu3, fenix847mm etc.),
     build the 50% larger font once with:
       SIZE=30 REF_SIZE=25 OUT_DIR=resources_${LANG}-large/fonts ./tools/build_font.sh $LANG
     Then map those devices in monkey.jungle so they pick resources_kor-large first.
  4) Rebuild the .prg (monkeyc -f monkey.jungle -d <device> ...) and test that the target
     line count is reasonable (~6 lines on large font, more on default).
EOF
