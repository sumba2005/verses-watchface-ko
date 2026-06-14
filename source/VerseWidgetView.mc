using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Application;

class VerseWidgetView extends WatchUi.View {

    private const LINE_GAP = 4;
    private var _ref = "";
    private var _verse = "";
    private var _lines = [];
    
    // Pagination state
    private var _currentPage = 0;
    private var _pageCount = 1;
    private var _linesPerPage = 4;

    function initialize() {
        View.initialize();
        loadCurrentVerse();  // Load immediately
    }

    function onShow() {
        if (_verse.length() == 0 || _ref.length() == 0) {
            loadCurrentVerse();
        }
        _currentPage = 0;
        WatchUi.requestUpdate();
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
            _verse = "Failed to load verse.";
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        if (_verse.length() == 0 || _ref.length() == 0) {
            loadCurrentVerse();
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var verseFont = Graphics.FONT_SYSTEM_MEDIUM;
        var refFont = Graphics.FONT_SYSTEM_SMALL;
        var fontH = dc.getFontHeight(verseFont);
        var lineH = fontH + LINE_GAP;
        
        var maxW = w - 30;
        _lines = wrapText(dc, _verse, verseFont, maxW);

        var regionTop = 20;
        var regionBot = h - 38;
        var regionH = regionBot - regionTop;
        _linesPerPage = (regionH / lineH).toNumber();
        if (_linesPerPage < 2) {
            _linesPerPage = 2;
        }
        
        _pageCount = ((_lines.size() + _linesPerPage - 1) / _linesPerPage).toNumber();
        if (_pageCount < 1) {
            _pageCount = 1;
        }
        if (_currentPage >= _pageCount) {
            _currentPage = 0;
        }

        var startLine = _currentPage * _linesPerPage;
        var endLine = startLine + _linesPerPage;
        if (endLine > _lines.size()) {
            endLine = _lines.size();
        }

        if (_pageCount > 1) {
            drawDots(dc, w, 8);
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var y = regionTop + ((regionH - (endLine - startLine) * lineH) / 2);
        for (var i = startLine; i < endLine; i++) {
            dc.drawText(w / 2, y, verseFont, _lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }

        dc.setColor(0xFF5555, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 18, refFont, _ref, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function drawDots(dc, w, dotY) {
        var r = 2;
        var spacing = 9;
        var totalW = (_pageCount - 1) * spacing;
        var x = (w - totalW) / 2;
        
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _pageCount; i++) {
            if (i == _currentPage) {
                dc.fillCircle(x, dotY, r + 1);
            } else {
                dc.drawCircle(x, dotY, r);
            }
            x += spacing;
        }
    }

    function nextPage() {
        if (_pageCount > 1) {
            _currentPage = (_currentPage + 1) % _pageCount;
            WatchUi.requestUpdate();
        }
    }

    private function wrapText(dc, text, font, maxW) {
        var lines = [];
        var words = splitWords(text);
        var current = "";
        
        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            var testLine = current.length() == 0 ? word : current + " " + word;
            if (dc.getTextWidthInPixels(testLine, font) <= maxW) {
                current = testLine;
            } else {
                if (current.length() > 0) {
                    lines.add(current);
                    current = word;
                } else {
                    lines.add(word);
                }
            }
        }
        if (current.length() > 0) {
            lines.add(current);
        }
        return lines;
    }

    private function splitWords(text) {
        var result = [];
        var word = "";
        for (var i = 0; i < text.length(); i++) {
            var ch = text.substring(i, i + 1);
            if (ch.equals(" ")) {
                if (word.length() > 0) {
                    result.add(word);
                    word = "";
                }
            } else {
                word += ch;
            }
        }
        if (word.length() > 0) {
            result.add(word);
        }
        return result;
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
