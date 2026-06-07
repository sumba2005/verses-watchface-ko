using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;

class VerseWidgetView extends WatchUi.View {

    private const LINE_GAP = 2;

    private var _font;
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
        loadCurrentVerse();
    }

    private function getProp(key, def) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? def : v;
    }

    private function loadCurrentVerse() {
        try {
            var data = WatchUi.loadResource(Rez.JsonData.Verses);
            if (data != null) {
                var versesList = data["v"];
                var books = data["b"];
                if (versesList != null && versesList.size() > 0) {
                    var interval = getProp("VerseInterval", 1);
                    var period = (interval == 0) ? 86400 : 3600;
                    var index = 0;
                    if (interval != 2) {
                        index = (Time.now().value() / period) % versesList.size();
                    }
                    var entry = versesList[index];
                    var bookIdx = entry[0];
                    var ch = entry[1];
                    var vn = entry[2];
                    _verse = entry[3];
                    _ref = books[bookIdx] + " " + ch.toString() + ":" + vn.toString();
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

        // Draw reference at the bottom (accent color matching default)
        dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h - 25, _font, _ref, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
}
