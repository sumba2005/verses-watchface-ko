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
// Battery notes: onUpdate runs once per minute in low-power mode, so CPU
// work here is minor next to the display itself. We cache what is free to
// cache (setting, stats, formatted time string), but we always do a full
// clear + redraw: the CIQ contract does not preserve the framebuffer
// between onUpdate calls, so partial redraws can leave stale content.
class BatterySaverView extends WatchUi.WatchFace {

    private var _lastStatsTime = 0;
    private var _cachedStats = null;
    private var _use24Hour = true;
    private var _lastFormattedMin = -1;
    private var _cachedTimeStr = "";

    function initialize() {
        WatchFace.initialize();
        _use24Hour = getProp("Use24Hour", true);
    }

    // Called by the app on onSettingsChanged so the cached setting and
    // formatted time string pick up the new value without a restart.
    function reloadSettings() {
        _use24Hour = getProp("Use24Hour", true);
        _lastFormattedMin = -1;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var clock = System.getClockTime();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var timeY = h / 2;

        // Date above time ONLY when min == 0; Time.now()/Gregorian.info()
        // are only queried in that one minute per hour.
        if (clock.min == 0) {
            var now = Time.now();
            var dateInfo = Gregorian.info(now, Time.FORMAT_SHORT);
            var dateStr = dateInfo.month.format("%d") + "/" + dateInfo.day.format("%d");
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, (h * 0.28).toNumber(), Graphics.FONT_SMALL, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
            timeY = (h * 0.48).toNumber();
        }

        // Time string is only reformatted when the minute changes.
        if (clock.min != _lastFormattedMin) {
            _lastFormattedMin = clock.min;
            if (_use24Hour) {
                _cachedTimeStr = clock.hour.format("%02d") + ":" + clock.min.format("%02d");
            } else {
                var h12 = clock.hour % 12;
                if (h12 == 0) { h12 = 12; }
                var ap = (clock.hour < 12) ? "AM" : "PM";
                _cachedTimeStr = h12.format("%02d") + ":" + clock.min.format("%02d") + " " + ap;
            }
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, timeY, Graphics.FONT_MEDIUM, _cachedTimeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Battery stats refresh every 5 minutes. getTimer() is a signed
        // 32-bit ms counter that wraps (~25 days); a negative delta means
        // it wrapped, so refresh then too.
        var now_ms = System.getTimer();
        var delta = now_ms - _lastStatsTime;
        if (_cachedStats == null || delta >= 300000 || delta < 0) {
            _cachedStats = System.getSystemStats();
            _lastStatsTime = now_ms;
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
        if (v == null) {
            return def;
        }
        if (def instanceof Toybox.Lang.Boolean) {
            if (v instanceof Toybox.Lang.Boolean) {
                return v;
            } else if (v instanceof Toybox.Lang.String) {
                var s = v.toLower();
                if ("true".equals(s) || "1".equals(s)) {
                    return true;
                } else if ("false".equals(s) || "0".equals(s)) {
                    return false;
                }
            } else if (v instanceof Toybox.Lang.Number) {
                return v != 0;
            }
        } else if (def instanceof Toybox.Lang.Number) {
            if (v instanceof Toybox.Lang.Number) {
                return v;
            } else if (v instanceof Toybox.Lang.String) {
                var num = v.toNumber();
                if (num != null) {
                    return num;
                }
                var flt = v.toFloat();
                if (flt != null) {
                    return flt.toNumber();
                }
            } else if (v instanceof Toybox.Lang.Float || v instanceof Toybox.Lang.Double) {
                return v.toNumber();
            }
        }
        return v;
    }
}

class BatterySaverDelegate extends WatchUi.WatchFaceDelegate {
    function initialize() {
        WatchFaceDelegate.initialize();
    }
}
