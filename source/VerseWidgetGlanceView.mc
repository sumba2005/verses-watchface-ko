using Toybox.WatchUi;
using Toybox.Graphics;

(:glance)
class VerseWidgetGlanceView extends WatchUi.GlanceView {
    
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc) {
        // Text completely removed per user request
        // Glance is now minimal (background only)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        
        // Optional small indicator (uncomment if you want a tiny mark)
        // dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        // dc.fillCircle(dc.getWidth()/2, dc.getHeight()/2, 3);
    }
}
