using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Math;
using Toybox.Application;
using Toybox.ActivityMonitor;

// Verses watch face: 12-hour time (top), Korean verse (middle), reference curved
// along the bottom arc. The verse changes hourly.
//
// Battery discipline: onUpdate() runs once per minute. The verse is loaded + wrapped
// only when the hour changes, then cached; per-minute work is just drawing the time
// + the cached verse lines. No seconds, so no onPartialUpdate.
//
// Pagination: Tap to enter pagination mode (FONT_MEDIUM, dots at top center).
// Fallback cascade: reduce reference radius → shrink region → truncate.
class VersesFaceView extends WatchUi.WatchFace {

    private const H_INSET_RATIO = 0.14;
    private const LINE_GAP = 1;
    private const DEBUG_INDEX = -1;
    private const REF_RADIUS_MIN = 0.37;   // min reference radius (conservative fallback)
    private const REGION_TOP_TIGHT = 0.16; // tight region top for fallback
    private const REGION_BOT_TIGHT = 0.80; // tight region bottom for fallback
    private const MAX_TRUNCATE_LINES = 4;
    private const PAGINATION_TIMEOUT = 10000; // milliseconds
    private const MAX_BOOK_NAME_LEN = 12;  // limit book name to stay within 7:30 rim edge

    private var _font;
    private var _loadedIdx = -1;
    private var _lastPeriodId = -1;
    private var _ref = "";
    private var _verse = "";
    private var _lines = [];
    private var _needWrap = false;
    private var _interval = 1;

    private var _steps = 0;
    private var _stepsAvailable = false;
    private var _lastStepUpdate = 0;

    // Pagination state
    private var _inPagination = false;
    private var _currentPage = 0;
    private var _pageCount = 1;
    private var _paginationLines = [];       // all lines for current verse (used in pagination mode)
    private var _paginationTimeout = 0;     // timestamp when pagination auto-exits
    private var _refRadiusAdjusted = false; // tracks if reference radius was reduced in cascade
    private var _regionAdjusted = false;    // tracks if region was shrunk in cascade

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        _font = WatchUi.loadResource(Rez.Fonts.VerseFont);
    }

    function onTap(clickEvent) {
        return handleTap(clickEvent);
    }

    private function handleTap(clickEvent) {
        if (!_inPagination) {
            enterPaginationMode();
        } else {
            nextPage();
        }
        WatchUi.requestUpdate();
        return true;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Check for pagination timeout
        var now = System.getTimer();
        if (_inPagination && now >= _paginationTimeout) {
            _inPagination = false;
            _currentPage = 0;
        }

        // User settings
        var use24    = getProp("Use24Hour", false);
        var showBatt = getProp("ShowBattery", true);
        var accent   = getProp("AccentColor", 0x55AAFF);
        var interval = getProp("VerseInterval", 1);

        if (interval != _interval) {
            _interval = interval;
            _loadedIdx = -1;
            _lastPeriodId = -1;
            _inPagination = false;
        }

        var period = (interval == 0) ? 86400 : 3600;
        var periodId = 0;
        if (interval != 2) {
            periodId = (Time.now().value() / period).toNumber();
        }

        if (periodId != _lastPeriodId || _loadedIdx == -1) {
            _lastPeriodId = periodId;
            try {
                var data = WatchUi.loadResource(Rez.JsonData.Verses);
                if (data != null) {
                    var versesList = data["v"];
                    var books = data["b"];
                    if (versesList != null && versesList.size() > 0) {
                        var idx = 0;
                        if (DEBUG_INDEX >= 0) {
                            idx = DEBUG_INDEX;
                        } else if (interval != 2) {
                            idx = periodId % versesList.size();
                        }
                        _loadedIdx = idx;
                        var entry = versesList[idx];
                        var bookIdx = entry[0];
                        var ch = entry[1];
                        var vn = entry[2];
                        _verse = entry[3];
                        var bookName = "";
                        if (books != null && bookIdx >= 0 && bookIdx < books.size()) {
                            bookName = books[bookIdx];
                            if (bookName.length() > MAX_BOOK_NAME_LEN) {
                                bookName = bookName.substring(0, MAX_BOOK_NAME_LEN);
                            }
                        }
                        _ref = bookName + " " + ch.toString() + ":" + vn.toString();
                        _needWrap = true;
                        _inPagination = false;
                        _currentPage = 0;
                        _refRadiusAdjusted = false;
                        _regionAdjusted = false;
                    }
                }
            } catch (ex) {
                _ref = "Error";
                _verse = "Failed to load verse data.";
                _needWrap = true;
            }
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var clock = System.getClockTime();

        // --- Time curved along the top rim ---
        var timeStr;
        if (use24) {
            timeStr = clock.hour.format("%02d") + ":" + clock.min.format("%02d");
        } else {
            var ap = (clock.hour < 12) ? "AM" : "PM";
            var h12 = clock.hour % 12;
            if (h12 == 0) { h12 = 12; }
            timeStr = h12.format("%02d") + ":" + clock.min.format("%02d") + " " + ap;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawArcText(dc, w / 2, h / 2, h * 0.44, timeStr, Graphics.FONT_SMALL, true);

        // --- Wrapping logic with collision detection ---
        if (_needWrap) {
            wrapWithCollisionDetection(dc, w, h);
            _needWrap = false;
        }

        // --- Draw verse (normal or pagination mode) ---
        if (_inPagination) {
            drawPaginationMode(dc, w, h, accent, showBatt);
        } else {
            drawNormalMode(dc, w, h, accent, showBatt);
        }
    }

    private function wrapWithCollisionDetection(dc, w, h) {
        var maxW = w - (2 * (w * H_INSET_RATIO).toNumber());

        // First wrap with normal settings
        if (_verse.length() > 50) {
            _lines = wrapCharacter(dc, _verse, _font, maxW);
        } else {
            _lines = wrapWords(dc, _verse, _font, maxW);
        }

        // Check collision with reference text (safe zone at h × 0.75)
        var lineH = dc.getFontHeight(_font) + LINE_GAP;
        var bodyH = _lines.size() * lineH;
        var regionTop = (h * 0.18).toNumber();
        var regionBot = (h * 0.75).toNumber(); // Safe zone
        var y = regionTop + (((regionBot - regionTop) - bodyH) / 2);

        // If verse extends past safe zone, apply fallback cascade
        if (y + bodyH > regionBot) {
            // Step 1: Try reducing reference radius
            _refRadiusAdjusted = true;
            // (Reference will be redrawn at smaller radius in drawNormalMode)

            // If still doesn't fit, re-wrap won't change it (no-op per design)

            // Step 2: Try shrinking region
            _regionAdjusted = true;
            regionTop = (h * REGION_TOP_TIGHT).toNumber();
            regionBot = (h * REGION_BOT_TIGHT).toNumber();
            bodyH = _lines.size() * lineH;
            y = regionTop + (((regionBot - regionTop) - bodyH) / 2);

            if (y + bodyH > regionBot) {
                // Step 3: Truncate to max lines
                truncateVerseToLines(dc, maxW, MAX_TRUNCATE_LINES);
                // Recalculate after truncation
                bodyH = _lines.size() * lineH;
            }
        }

        // Cache all lines for pagination
        _paginationLines = [];
        for (var i = 0; i < _lines.size(); i++) {
            _paginationLines.add(_lines[i]);
        }

        // Calculate pages for FONT_MEDIUM pagination
        calculatePaginationPages(dc);
    }

    private function calculatePaginationPages(dc) {
        // How many lines fit per page in the custom font?
        var pageLineH = dc.getFontHeight(_font) + LINE_GAP;
        var regionH = ((REGION_BOT_TIGHT - REGION_TOP_TIGHT) * dc.getHeight()).toNumber();
        var linesPerPage = (regionH / pageLineH).toNumber();
        if (linesPerPage < 1) { linesPerPage = 1; }

        _pageCount = ((_paginationLines.size() + linesPerPage - 1) / linesPerPage).toNumber();
        if (_pageCount < 1) { _pageCount = 1; }
    }

    private function truncateVerseToLines(dc, maxW, maxLines) {
        var truncated = [];
        for (var i = 0; i < _lines.size() && i < maxLines; i++) {
            truncated.add(_lines[i]);
        }
        if (_lines.size() > maxLines) {
            truncated[maxLines - 1] += "...";
        }
        _lines = truncated;
    }

    private function drawNormalMode(dc, w, h, accent, showBatt) {
        var lineH = dc.getFontHeight(_font) + LINE_GAP;
        var bodyH = _lines.size() * lineH;
        var regionTop = _regionAdjusted ? (h * REGION_TOP_TIGHT).toNumber() : (h * 0.18).toNumber();
        var regionBot = _regionAdjusted ? (h * REGION_BOT_TIGHT).toNumber() : (h * 0.84).toNumber();
        var y = regionTop + (((regionBot - regionTop) - bodyH) / 2);
        if (y < regionTop) { y = regionTop; }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _lines.size(); i++) {
            dc.drawText(w / 2, y, _font, _lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }

        // Reference arc with adjusted radius if needed
        var refRadius = _refRadiusAdjusted ? (h * REF_RADIUS_MIN) : (h * 0.40);
        drawArcTextColored(dc, w / 2, h / 2, refRadius, _ref, Graphics.FONT_XTINY, accent, 0xFF5555);

        // Battery and pedometer
        if (showBatt) {
            var batt = System.getSystemStats().battery;
            var battStr = batt.format("%d") + "%";
            dc.setColor(batt <= 15 ? 0xFF5555 : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawVerticalText(dc, (w * 0.07).toNumber(), h / 2, Graphics.FONT_XTINY, battStr);
        }

        var showPedo = getProp("ShowPedometer", true);
        if (showPedo) {
            var now = Time.now().value();
            if (now - _lastStepUpdate >= 300) {
                _lastStepUpdate = now;
                updateSteps();
            }
            var pedoStr = _stepsAvailable ? _steps.toString() : "--";
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawVerticalText(dc, (w * 0.93).toNumber(), h / 2, Graphics.FONT_XTINY, pedoStr);
        }
    }

    private function drawPaginationMode(dc, w, h, accent, showBatt) {
        // Everything shrinks proportionally
        var pageLineH = dc.getFontHeight(_font) + LINE_GAP;
        var regionTop = (h * REGION_TOP_TIGHT).toNumber();
        var regionBot = (h * REGION_BOT_TIGHT).toNumber();
        var regionH = regionBot - regionTop;
        var linesPerPage = (regionH / pageLineH).toNumber();

        var startLine = _currentPage * linesPerPage;
        var endLine = startLine + linesPerPage;
        if (endLine > _paginationLines.size()) { endLine = _paginationLines.size(); }

        var y = regionTop + 10;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = startLine; i < endLine; i++) {
            dc.drawText(w / 2, y, _font, _paginationLines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += pageLineH;
        }

        // Draw dots at top center (only if multi-page)
        if (_pageCount > 1) {
            drawPaginationDots(dc, w, h);
        }

        // Reference arc (adjusted radius)
        var refRadius = _refRadiusAdjusted ? (h * REF_RADIUS_MIN) : (h * 0.40);
        drawArcTextColored(dc, w / 2, h / 2, refRadius, _ref, Graphics.FONT_XTINY, accent, 0xFF5555);

        // Battery and pedometer (scaled down)
        if (showBatt) {
            var batt = System.getSystemStats().battery;
            var battStr = batt.format("%d") + "%";
            dc.setColor(batt <= 15 ? 0xFF5555 : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawVerticalText(dc, (w * 0.07).toNumber(), h / 2, Graphics.FONT_XTINY, battStr);
        }

        var showPedo = getProp("ShowPedometer", true);
        if (showPedo) {
            var now = Time.now().value();
            if (now - _lastStepUpdate >= 300) {
                _lastStepUpdate = now;
                updateSteps();
            }
            var pedoStr = _stepsAvailable ? _steps.toString() : "--";
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawVerticalText(dc, (w * 0.93).toNumber(), h / 2, Graphics.FONT_XTINY, pedoStr);
        }
    }

    private function drawPaginationDots(dc, w, h) {
        var dotRadius = 3;
        var spacing = 12;
        var totalWidth = (_pageCount - 1) * spacing;
        var startX = w / 2 - (totalWidth / 2);
        var dotY = (h * 0.12).toNumber();

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

    // Public methods for InputDelegate
    function isPaginating() {
        return _inPagination;
    }

    function enterPaginationMode() {
        _inPagination = true;
        _currentPage = 0;
        _paginationTimeout = System.getTimer() + PAGINATION_TIMEOUT;
    }

    function nextPage() {
        _currentPage = (_currentPage + 1) % _pageCount;
        _paginationTimeout = System.getTimer() + PAGINATION_TIMEOUT;
    }

    // Read an Application property, falling back to def if unset/null.
    private function getProp(key, def) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? def : v;
    }

    // Draw text stacked vertically (one glyph per row), centered on cy. Used for the
    // 9 o'clock battery so the digits read top-to-bottom down the left rim.
    private function drawVerticalText(dc, x, cy, font, text) {
        var n = text.length();
        var ch = dc.getFontHeight(font);
        var y = cy - ((n * ch) / 2) + (ch / 2);
        for (var i = 0; i < n; i++) {
            dc.drawText(x, y, font, text.substring(i, i + 1),
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            y += ch;
        }
    }


// Draw text along an arc with two colors: book name in color1, chapter:verse in color2
    private function drawArcTextColored(dc, cx, cy, radius, text, font, color1, color2) {
        // Find the last space to split book name and chapter:verse
        var spaceIdx = -1;
        for (var i = text.length() - 1; i >= 0; i--) {
            if (text.substring(i, i + 1).equals(" ")) {
                spaceIdx = i;
                break;
            }
        }

        if (spaceIdx == -1) {
            dc.setColor(color2, Graphics.COLOR_TRANSPARENT);
            drawArcText(dc, cx, cy, radius, text, font, false);
            return;
        }

        var bookName = text.substring(0, spaceIdx);
        var chapterVerse = text.substring(spaceIdx + 1, text.length());

        // Calculate total width
        var totalW = 0.0;
        for (var i = 0; i < text.length(); i++) {
            totalW += dc.getTextWidthInPixels(text.substring(i, i + 1), font);
        }

        var spaceW = dc.getTextWidthInPixels(" ", font);

        // Starting angle (centered at 6 o'clock)
        var a = -(totalW / radius) / 2.0;

        // Draw book name in color1
        dc.setColor(color1, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < bookName.length(); i++) {
            var ch = bookName.substring(i, i + 1);
            var cw = dc.getTextWidthInPixels(ch, font);
            var mid = a + (cw / 2.0) / radius;
            var x = cx + (radius * Math.sin(mid));
            var yy = cy + (radius * Math.cos(mid));
            dc.drawText(x, yy, font, ch,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            a += cw / radius;
        }

        // Advance angle past the space (invisible glyph)
        a += spaceW / radius;

        // Draw chapter:verse in color2
        dc.setColor(color2, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < chapterVerse.length(); i++) {
            var ch = chapterVerse.substring(i, i + 1);
            var cw = dc.getTextWidthInPixels(ch, font);
            var mid = a + (cw / 2.0) / radius;
            var x = cx + (radius * Math.sin(mid));
            var yy = cy + (radius * Math.cos(mid));
            dc.drawText(x, yy, font, ch,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            a += cw / radius;
        }
    }

// Draw text along an arc. top=true centers it at 12 o'clock (text reads left to
    // right across the top rim); top=false centers it at 6 o'clock along the bottom.
    // The 4S has no text rotation API, so glyphs stay upright; only their position
    // follows the curve.
    private function drawArcText(dc, cx, cy, radius, text, font, top) {
        var n = text.length();
        var total = 0.0;
        for (var i = 0; i < n; i++) {
            total += dc.getTextWidthInPixels(text.substring(i, i + 1), font);
        }
        var a = -(total / radius) / 2.0;          // leftmost angle (radians from center)
        for (var i = 0; i < n; i++) {
            var ch = text.substring(i, i + 1);
            var cw = dc.getTextWidthInPixels(ch, font);
            var mid = a + (cw / 2.0) / radius;
            var x = cx + (radius * Math.sin(mid));
            var yy = top ? (cy - (radius * Math.cos(mid)))
                         : (cy + (radius * Math.cos(mid)));
            dc.drawText(x, yy, font, ch,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            a += cw / radius;
        }
    }



    private function updateSteps() {
        try {
            var info = ActivityMonitor.getInfo();
            if (info != null && info.steps != null) {
                _steps = info.steps;
                _stepsAvailable = true;
            } else {
                _stepsAvailable = false;
            }
        } catch (ex) {
            _stepsAvailable = false;
        }
    }

    // Word-based wrapping with space breaks (for shorter verses).
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

    // Character-level wrapping for maximum line usage (for longer verses >50 chars).
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
