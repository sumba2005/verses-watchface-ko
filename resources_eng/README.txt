English build scaffold — NOT yet buildable (needs content).

To finish the English face, drop in:

  1) verses-eng.csv at the project root
     Format (pipe-delimited, ASCII):  book|chapter_number|verse_number|verse
     Example:  John|1|2|The same was in the beginning with God

  2) Generate the JSON + glyph set:
       python3 tools/build_resources.py eng
     -> resources-eng/data/verses.json
     -> tools/glyphs-eng.txt   (Latin glyphs only — tiny font)

  3) Build the Latin glyph-subset font:
       TTF=tools/<SomeLatinFont>.ttf tools/build_font.sh eng
     -> resources-eng/fonts/verse.fnt + verse.png + fonts.xml
     (and resources-eng-vivoactive4s/fonts/* if you want a smaller 4S size)

  4) Build:
       monkeyc -f eng.jungle -o bin/verses-eng-4s.prg -y developer_key -d vivoactive4s
       tools/sideload.sh eng

The English face has its own app id (manifest-eng.xml), so it coexists with
the Korean face on the watch and as a separate store listing.
