using Toybox.Application;
using Toybox.WatchUi;

(:glance)
class VerseWidgetApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new VerseWidgetView();
        var delegate = new VerseWidgetDelegate(view);
        return [ view, delegate ];
    }

    // Glance support (Connect IQ 3.1+)
    (:glance)
    function getGlanceView() {
        return [ new VerseWidgetGlanceView() ];
    }
}
