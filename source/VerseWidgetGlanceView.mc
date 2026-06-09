using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;

(:glance)
class VerseWidgetGlanceView extends WatchUi.GlanceView {
    
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        
        // Draw AppName ("말씀" or "Verses")
        var appName = WatchUi.loadResource(Rez.Strings.AppName);
        dc.drawText(10, (h / 2) - 15, Graphics.FONT_TINY, appName, Graphics.TEXT_JUSTIFY_LEFT);
        
        // Draw subtitle ("오늘의 말씀" / "Today's Verse")
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var subtitle = (appName.equals("말씀")) ? "오늘의 말씀" : "Today's Verse";
        dc.drawText(10, (h / 2) + 4, Graphics.FONT_XTINY, subtitle, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
