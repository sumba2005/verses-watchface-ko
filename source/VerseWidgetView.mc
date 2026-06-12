using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;

class VerseWidgetView extends WatchUi.View {

    private const LINE_GAP = 2;

    private var _font;
    private var _refFont;
    private var _ref = "";
    private var _verse = "";
    private var _lines = [];
    
    // Pagination state
    private var _currentPage = 0;
    private var _pageCount = 1;
    private var _linesPerPage = 3;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc) {
        _font = WatchUi.loadResource(Rez.Fonts.VerseFont);
        _refFont = WatchUi.loadResource(Rez.Fonts.RefFont);
        loadCurrentVerse();
    }

    private function getProp(key, def) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? def : v;
    }

    private function loadCurrentVerse() {
        try {
            var meta = WatchUi.loadResource(Rez.JsonData.VersesMeta);
            if (meta != null) {
                var total = meta["total"];
                var interval = getProp("VerseInterval", 1);
                var period = (interval == 0) ? 86400 : 3600;
                var index = 0;
                if (interval != 2) {
                    index = (Time.now().value() / period) % total;
                }
                
                var chunkId = (index / 20).toNumber();
                var chunkIdx = index % 20;

                var data = loadChunk(chunkId);
                if (data != null) {
                    var versesList = data["v"];
                    var books = data["b"];
                    if (versesList != null && chunkIdx < versesList.size()) {
                        var entry = versesList[chunkIdx];
                        var bookIdx = entry[0];
                        var ch = entry[1];
                        var vn = entry[2];
                        _verse = entry[3];
                        _ref = books[bookIdx] + " " + ch.toString() + ":" + vn.toString();
                    }
                }
            }
        } catch (ex) {
            _ref = "Error";
            _verse = "Failed to load verse data.";
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // Calculate line heights and spacing
        var fontH = dc.getFontHeight(_font);
        var pageLineH = fontH + LINE_GAP;
        
        // Wrap text based on screen width
        var maxW = w - 40;
        if (_verse.length() > 50) {
            _lines = wrapCharacter(dc, _verse, _font, maxW);
        } else {
            _lines = wrapWords(dc, _verse, _font, maxW);
        }

        // Calculate pagination parameters
        var regionTop = 35;
        var regionBot = h - 35;
        var regionH = regionBot - regionTop;
        _linesPerPage = (regionH / pageLineH).toNumber();
        if (_linesPerPage < 1) { _linesPerPage = 1; }

        _pageCount = ((_lines.size() + _linesPerPage - 1) / _linesPerPage).toNumber();
        if (_pageCount < 1) { _pageCount = 1; }
        if (_currentPage >= _pageCount) { _currentPage = 0; }

        var startLine = _currentPage * _linesPerPage;
        var endLine = startLine + _linesPerPage;
        if (endLine > _lines.size()) { endLine = _lines.size(); }

        // Draw page dots if multi-page
        if (_pageCount > 1) {
            drawDots(dc, w, 20);
        }

        // Draw verse text
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var bodyH = (endLine - startLine) * pageLineH;
        var y = regionTop + ((regionH - bodyH) / 2);
        for (var i = startLine; i < endLine; i++) {
            dc.drawText(w / 2, y, _font, _lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += pageLineH;
        }

        // Draw reference at the bottom (book name in red, chapter:verse in accent)
        var spaceIdx = -1;
        for (var i = _ref.length() - 1; i >= 0; i--) {
            if (_ref.substring(i, i + 1).equals(" ")) {
                spaceIdx = i;
                break;
            }
        }
        if (spaceIdx == -1) {
            dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h - 25, _refFont, _ref, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            var bookName = _ref.substring(0, spaceIdx);
            var chapterVerse = _ref.substring(spaceIdx + 1, _ref.length());
            
            var bookW = dc.getTextWidthInPixels(bookName, _refFont);
            var spaceW = dc.getTextWidthInPixels(" ", _refFont);
            var cvW = dc.getTextWidthInPixels(chapterVerse, _refFont);
            var totalW = bookW + spaceW + cvW;

            var startX = (w - totalW) / 2;
            var yY = h - 25;

            dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT); // Red
            dc.drawText(startX + (bookW / 2), yY, _refFont, bookName, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT); // Red
            dc.drawText(startX + bookW + spaceW + (cvW / 2), yY, _refFont, chapterVerse, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function drawDots(dc, w, dotY) {
        var dotRadius = 3;
        var spacing = 12;
        var totalWidth = (_pageCount - 1) * spacing;
        var startX = w / 2 - (totalWidth / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _pageCount; i++) {
            var x = startX + (i * spacing);
            if (i == _currentPage) {
                dc.fillCircle(x, dotY, dotRadius);
            } else {
                dc.drawCircle(x, dotY, dotRadius);
            }
        }
    }

    function nextPage() {
        if (_pageCount > 1) {
            _currentPage = (_currentPage + 1) % _pageCount;
        }
    }

    // Word wrapping functions (copied from watchface for consistency)
    private function wrapWords(dc, text, font, maxW) {
        var lines = [];
        var words = splitSpaces(text);
        var cur = "";
        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            var test = (cur.length() == 0) ? word : cur + " " + word;
            if (dc.getTextWidthInPixels(test, font) <= maxW) {
                cur = test;
            } else {
                if (cur.length() > 0) { lines.add(cur); cur = ""; }
                cur = word;
            }
        }
        if (cur.length() > 0) { lines.add(cur); }
        return lines;
    }

    private function wrapCharacter(dc, text, font, maxW) {
        var lines = [];
        var cur = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            var test = cur + ch;
            if (dc.getTextWidthInPixels(test, font) <= maxW) {
                cur = test;
            } else {
                if (cur.length() > 0) { lines.add(cur); }
                cur = ch;
            }
        }
        if (cur.length() > 0) { lines.add(cur); }
        return lines;
    }

    private function splitSpaces(text) {
        var out = [];
        var cur = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals(" ")) {
                if (cur.length() > 0) { out.add(cur); cur = ""; }
            } else {
                cur += ch;
            }
        }
        if (cur.length() > 0) { out.add(cur); }
        return out;
    }

    private function loadChunk(chunkId) {
        if (chunkId == 0) { return WatchUi.loadResource(Rez.JsonData.verses_0); }
        if (chunkId == 1) { return WatchUi.loadResource(Rez.JsonData.verses_1); }
        if (chunkId == 2) { return WatchUi.loadResource(Rez.JsonData.verses_2); }
        if (chunkId == 3) { return WatchUi.loadResource(Rez.JsonData.verses_3); }
        if (chunkId == 4) { return WatchUi.loadResource(Rez.JsonData.verses_4); }
        if (chunkId == 5) { return WatchUi.loadResource(Rez.JsonData.verses_5); }
        if (chunkId == 6) { return WatchUi.loadResource(Rez.JsonData.verses_6); }
        if (chunkId == 7) { return WatchUi.loadResource(Rez.JsonData.verses_7); }
        if (chunkId == 8) { return WatchUi.loadResource(Rez.JsonData.verses_8); }
        if (chunkId == 9) { return WatchUi.loadResource(Rez.JsonData.verses_9); }
        return null;
    }

}
