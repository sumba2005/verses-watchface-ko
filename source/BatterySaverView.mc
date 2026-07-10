using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Application;
using Toybox.Time.Gregorian;

// Battery saver watchface with settings for 24h/12h.
// - Centered time (FONT_MEDIUM).
// - Date above time ONLY when min == 0.
// - Battery % at top center when charging && >50%.
//
// Phase 1 optimizations: Lazy-load time queries, cache battery stats
class BatterySaverView extends WatchUi.WatchFace {

    private var _lastStatsTime = 0;
    private var _cachedStats = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var clock = System.getClockTime();
        var use24 = getProp("Use24Hour", true);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var timeY = h / 2;

        // Phase 1 Optimization: Lazy-load Time.now() and Gregorian.info()
        // Previously called every minute, now only called when date is displayed
        // Date above time ONLY when min == 0 (top of every hour)
        if (clock.min == 0) {
            var now = Time.now();
            var dateInfo = Gregorian.info(now, Time.FORMAT_SHORT);
            var dateStr = dateInfo.month.format("%d") + "/" + dateInfo.day.format("%d");
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, (h * 0.28).toNumber(), Graphics.FONT_SMALL, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
            timeY = (h * 0.48).toNumber();
        }

        // Time with 24h or 12h based on setting
        var timeStr;
        if (use24) {
            timeStr = clock.hour.format("%02d") + ":" + clock.min.format("%02d");
        } else {
            var h12 = clock.hour % 12;
            if (h12 == 0) { h12 = 12; }
            var ap = (clock.hour < 12) ? "AM" : "PM";
            timeStr = h12.format("%02d") + ":" + clock.min.format("%02d") + " " + ap;
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, timeY, Graphics.FONT_MEDIUM, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Phase 1 Optimization: Cache battery stats, refresh every 5 minutes instead of 60s
        // Battery level changes ~5-10% per hour; polling every 5 minutes is sufficient
        var now_sec = System.getElapsedTime();
        if (_cachedStats == null || (now_sec - _lastStatsTime) >= 300) {
            _cachedStats = System.getSystemStats();
            _lastStatsTime = now_sec;
        }
        var stats = _cachedStats;

        // Battery % at top center when charging && >50%
        if (stats.charging && stats.battery > 50) {
            var battStr = stats.battery.format("%d") + "%";
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, (h * 0.12).toNumber(), Graphics.FONT_XTINY, battStr, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function getProp(key, def) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? def : v;
    }
}

class BatterySaverDelegate extends WatchUi.WatchFaceDelegate {
    function initialize() {
        WatchFaceDelegate.initialize();
    }
}
