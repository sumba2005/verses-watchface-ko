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
if [ "$LANG" = "kor" ]; then
    DEFAULT_TTF="tools/NotoSansKR-Regular.ttf"
else
    DEFAULT_TTF="tools/NotoSans-Regular.ttf"
fi
TTF="${TTF:-$DEFAULT_TTF}"
SIZE="${SIZE:-30}"                            # point size; tune so all verses fit one screen
GLYPHS="tools/glyphs-$LANG.txt"
OUT_DIR="resources-$LANG/fonts"
OUT="$OUT_DIR/verse"

[ -f "$GLYPHS" ] || { echo "Missing $GLYPHS — run: python3 tools/build_resources.py $LANG"; exit 1; }
[ -f "$TTF" ]    || { echo "Missing font TTF at $TTF (set TTF=/path/to.ttf)"; exit 1; }
command -v fontbm >/dev/null || { echo "fontbm not found — see header for install link"; exit 1; }

mkdir -p "$OUT_DIR"

fontbm \
  --font-file "$TTF" \
  --font-size "$SIZE" \
  --chars-file "$GLYPHS" \
  --texture-size 512x512 \
  --color 255,255,255 \
  --output "$OUT"

echo "Generated $OUT.fnt + $OUT.png  (lang=$LANG)"
cat <<EOF

Next:
  1) Ensure resources-$LANG/fonts/fonts.xml exists:
       <resources>
         <font id="VerseFont" filename="verse.fnt"/>
       </resources>
  2) (4S only) for a smaller screen font, re-run with SIZE lower and copy the
     output into resources-$LANG-vivoactive4s/fonts/ (device qualifier override).
  3) Rebuild and verify in the simulator that all verses fit one screen;
     if any overflow, lower SIZE and re-run.
EOF
