using Toybox.Application;
using Toybox.WatchUi;

// Minimal battery saver app - only time display HH:MM
class BatterySaverApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new BatterySaverView();
        var delegate = new BatterySaverDelegate();
        return [ view, delegate ];
    }

    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
