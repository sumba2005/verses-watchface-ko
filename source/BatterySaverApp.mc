using Toybox.Application;
using Toybox.WatchUi;

// Minimal battery saver app - only time display HH:MM
class BatterySaverApp extends Application.AppBase {

    private var _view = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        _view = new BatterySaverView();
        var delegate = new BatterySaverDelegate();
        return [ _view, delegate ];
    }

    function onSettingsChanged() {
        if (_view != null) {
            _view.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
