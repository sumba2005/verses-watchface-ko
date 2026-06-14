using Toybox.Application;
using Toybox.WatchUi;

class VerseWidgetApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new VerseWidgetView();
        var delegate = new VerseWidgetDelegate(view);
        return [ view, delegate ];
    }
}
