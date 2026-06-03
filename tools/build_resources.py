#!/usr/bin/env python3
"""Build Connect IQ resources for one language from verses-<lang>.csv.

Per-language builds keep each binary lean: only the chosen language's verses
and glyph-subset font ship. Pass the language code as the first argument.

Outputs (for lang=kor):
  resources-kor/data/verses.json - JSON array of {r: "<reference>", t: "<verse text>"}
                                    loaded on demand (one verse shown per period).
  tools/glyphs-kor.txt           - the exact unique glyph set used by all verses +
                                    references, fed to the font subsetter so the
                                    embedded font carries only glyphs we render.

Run from the project root:  python3 tools/build_resources.py [lang]   (default: kor)
"""
import csv, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG = (sys.argv[1] if len(sys.argv) > 1 else "kor").strip().lower()
SRC  = os.path.join(ROOT, f"verses-{LANG}.csv")
OUT_JSON = os.path.join(ROOT, f"resources-{LANG}", "data", "verses.json")
OUT_GLYPHS = os.path.join(ROOT, "tools", f"glyphs-{LANG}.txt")

def main():
    if not os.path.exists(SRC):
        sys.exit(f"missing {SRC} (expected verses-{LANG}.csv at project root)")

    verses = []
    with open(SRC, encoding="utf-8") as f:
        r = csv.reader(f, delimiter="|")
        header = next(r)
        for row in r:
            if len(row) < 4:
                continue
            book, ch, vn, text = row[0].strip(), row[1].strip(), row[2].strip(), row[3].strip()
            ref = f"{book} {ch}:{vn}"
            verses.append({"r": ref, "t": text})

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(verses, f, ensure_ascii=False, separators=(",", ":"))

    # Glyph set: every character that can ever be drawn (references + verse bodies).
    glyphs = set()
    for v in verses:
        glyphs.update(v["r"])
        glyphs.update(v["t"])
    glyphs.discard("\n")
    ordered = "".join(sorted(glyphs))
    with open(OUT_GLYPHS, "w", encoding="utf-8") as f:
        f.write(ordered)

    hangul = [c for c in glyphs if "가" <= c <= "힣"]
    print(f"language       : {LANG}")
    print(f"verses written : {len(verses)}  -> {os.path.relpath(OUT_JSON, ROOT)}")
    print(f"json bytes      : {os.path.getsize(OUT_JSON)}")
    print(f"unique glyphs   : {len(glyphs)} (Hangul syllables: {len(hangul)})")
    print(f"glyph list      : {os.path.relpath(OUT_GLYPHS, ROOT)}")

if __name__ == "__main__":
    main()
