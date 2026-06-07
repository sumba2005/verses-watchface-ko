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
OUT_JSON = os.path.join(ROOT, f"resources_{LANG}", "data", "verses.json")
OUT_GLYPHS = os.path.join(ROOT, "tools", f"glyphs-{LANG}.txt")

KOREAN_BOOK_ABBREVIATIONS = {
    # Old Testament
    "창세기": "창", "출애굽기": "출", "레위기": "레", "민수기": "민", "신명기": "신",
    "여호수아": "수", "사사기": "삿", "룻기": "룻", "사무엘상": "삼상", "사무엘하": "삼하",
    "열왕기상": "왕상", "열왕기하": "왕하", "역대상": "대상", "역대하": "대하", "에스라": "스",
    "느헤미야": "느", "에스더": "에", "욥기": "욥", "시편": "시", "잠언": "잠",
    "전도서": "전", "아가": "아", "이사야": "사", "예레미야": "렘", "예레미야애가": "애",
    "에스겔": "겔", "다니엘": "단", "호세아": "호", "요엘": "욜", "아모스": "암",
    "오바댜": "옵", "요나": "욘", "미가": "미", "나훔": "나", "하박국": "합",
    "스바냐": "습", "학개": "학", "스가랴": "슥", "말라기": "말",
    # New Testament
    "마태복음": "마", "마가복음": "막", "누가복음": "눅", "요한복음": "요", "사도행전": "행",
    "로마서": "롬", "고린도전서": "고전", "고린도후서": "고후", "갈라디아서": "갈", "에베소서": "엡",
    "빌립보서": "빌", "골로새서": "골", "데살로니가전서": "살전", "데살로니가후서": "살후",
    "디모데전서": "딤전", "디모데후서": "딤후", "디도서": "딛", "빌레몬서": "몬", "히브리서": "히",
    "야고보서": "약", "베드로전서": "벧전", "베드로후서": "벧후", "요한일서": "요일",
    "요한이서": "요이", "요한삼서": "요삼", "유다서": "유", "요한계시록": "계"
}

def main():
    if not os.path.exists(SRC):
        sys.exit(f"missing {SRC} (expected verses-{LANG}.csv at project root)")

    books = []
    book_to_idx = {}
    verses = []
    
    with open(SRC, encoding="utf-8") as f:
        r = csv.reader(f, delimiter="|")
        header = next(r)
        for row in r:
            if len(row) < 4:
                continue
            book, ch, vn, text = row[0].strip(), row[1].strip(), row[2].strip(), row[3].strip()
            
            if len(book) >= 4 and book in KOREAN_BOOK_ABBREVIATIONS:
                book = KOREAN_BOOK_ABBREVIATIONS[book]
                
            if book not in book_to_idx:
                book_to_idx[book] = len(books)
                books.append(book)
            book_idx = book_to_idx[book]
            
            try:
                ch_val = int(ch)
            except ValueError:
                ch_val = ch
            try:
                vn_val = int(vn)
            except ValueError:
                vn_val = vn
                
            verses.append([book_idx, ch_val, vn_val, text])

    output_data = {
        "b": books,
        "v": verses
    }

    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, separators=(",", ":"))

    # Glyph set: every character that can ever be drawn (references + verse bodies).
    glyphs = set()
    for book in books:
        glyphs.update(book)
    for v in verses:
        glyphs.update(str(v[1]))
        glyphs.update(str(v[2]))
        glyphs.update(v[3])
        
    glyphs.discard("\n")
    # Always include basic punctuation and reference formatting characters
    glyphs.update([".", "-", "…", " ", ":"])
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
