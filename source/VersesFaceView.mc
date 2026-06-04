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
class VersesFaceView extends WatchUi.WatchFace {

    private const VERSE_COUNT = 241;
    private const H_INSET_RATIO = 0.14;
    private const LINE_GAP = 1;
    private const DEBUG_INDEX = -1;        // -1 = daily verse; >=0 forces a fixed verse (testing)

    private var _font;
    private var _loadedIdx = -1;
    private var _ref = "";
    private var _verse = "";
    private var _lines = [];
    private var _needWrap = false;
    private var _interval = 1;              // tracks VerseInterval to invalidate the cache on change
    private var _heartRate = "--";
    private var _steps = "--";

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc) {
        _font = WatchUi.loadResource(Rez.Fonts.VerseFont);
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();

        // User settings (Garmin Connect Mobile / on-device), read each draw.
        var use24    = getProp("Use24Hour", false);
        var showBatt = getProp("ShowBattery", true);
        var accent   = getProp("AccentColor", 0x55AAFF);
        var interval = getProp("VerseInterval", 1);

        // Changing the rotation interval changes which verse is "current",
        // so invalidate the cache and force a reload + re-wrap.
        if (interval != _interval) {
            _interval = interval;
            _loadedIdx = -1;
        }

        // Refresh the verse only when the active index changes.
        var idx = verseIndex(interval);
        if (idx != _loadedIdx) {
            _loadedIdx = idx;
            loadVerse(idx);
            _needWrap = true;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var clock = System.getClockTime();

        // --- Time curved along the top rim (11 -> 12 -> 1 o'clock) ---
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

        // --- Verse (lower half) ---
        if (_needWrap) {
            var maxW = w - (2 * (w * H_INSET_RATIO).toNumber());
            _lines = wrap(dc, _verse, _font, maxW);
            _needWrap = false;
        }
        var lineH = dc.getFontHeight(_font) + LINE_GAP;
        var bodyH = _lines.size() * lineH;
        var regionTop = (h * 0.22).toNumber();
        var regionBot = (h * 0.80).toNumber();
        var y = regionTop + (((regionBot - regionTop) - bodyH) / 2);
        if (y < regionTop) { y = regionTop; }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _lines.size(); i++) {
            dc.drawText(w / 2, y, _font, _lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineH;
        }

        // --- Reference, below the verse, along the bottom arc (8 -> 6 -> 4 o'clock) ---
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        drawArcText(dc, w / 2, h / 2, h * 0.40, _ref, _font, false);

        // --- Battery, stacked vertically at the 9 o'clock rim edge (optional) ---
        if (showBatt) {
            var batt = System.getSystemStats().battery;   // 0..100 float
            var battStr = batt.format("%d") + "%";
            dc.setColor(batt <= 15 ? 0xFF5555 : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawVerticalText(dc, (w * 0.07).toNumber(), h / 2, Graphics.FONT_XTINY, battStr);
        }

        // --- HR and steps, displayed horizontally below the verse ---
        updateHeartRateAndSteps();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var metricsY = (h * 0.82).toNumber();
        var hrText = _heartRate + " bpm";
        var stepsText = _steps + " steps";
        var spacing = 20;
        dc.drawText(w / 2 - spacing, metricsY, Graphics.FONT_SMALL, hrText, Graphics.TEXT_JUSTIFY_RIGHT);
        dc.drawText(w / 2 + spacing, metricsY, Graphics.FONT_SMALL, stepsText, Graphics.TEXT_JUSTIFY_LEFT);
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


    // Fetch current HR and steps, cache in _heartRate and _steps.
    private function updateHeartRateAndSteps() {
        // Heart rate: API not available in vivoactive4s; show placeholder
        _heartRate = "--";

        // Steps: read from ActivityMonitor
        var actInfo = ActivityMonitor.getInfo();
        if (actInfo != null && actInfo.steps != null) {
            var stepCount = actInfo.steps;
            if (stepCount >= 1000) {
                _steps = (stepCount / 1000).format("%.1f") + "k";
            } else {
                _steps = stepCount.format("%d");
            }
        } else {
            _steps = "--";
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

    // Which verse is "current", per the user's rotation setting. Deterministic,
    // no stored state. interval: 0=daily, 1=hourly, 2=fixed (first verse).
    private function verseIndex(interval) {
        if (DEBUG_INDEX >= 0) {
            return DEBUG_INDEX;
        }
        if (interval == 2) {
            return 0;
        }
        var period = (interval == 0) ? 86400 : 3600;   // daily : hourly
        return (Time.now().value() / period) % VERSE_COUNT;
    }

    private function loadVerse(idx) {
        var data = WatchUi.loadResource(Rez.JsonData.Verses);
        var entry = data[idx];
        _ref = entry["r"];
        _verse = entry["t"];
    }

    // Greedy space-based wrap with char-level fallback (runs only on day change).
    private function wrap(dc, text, font, maxW) {
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
                if (dc.getTextWidthInPixels(word, font) > maxW) {
                    var chunk = "";
                    for (var c = 0; c < word.length(); c++) {
                        var ch = word.substring(c, c + 1);
                        var t2 = chunk + ch;
                        if (dc.getTextWidthInPixels(t2, font) <= maxW) {
                            chunk = t2;
                        } else {
                            if (chunk.length() > 0) { lines.add(chunk); }
                            chunk = ch;
                        }
                    }
                    cur = chunk;
                } else {
                    cur = word;
                }
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
