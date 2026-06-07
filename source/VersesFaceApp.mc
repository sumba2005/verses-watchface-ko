using Toybox.Application;
using Toybox.WatchUi;

// Watch face entry point. No background service, no permissions.
class VersesFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new VersesFaceView();
        var delegate = new VersesFaceDelegate(view);
        return [ view, delegate ];
    }

    // Fired when the user changes settings in Garmin Connect Mobile / on-device.
    // Repaint so the new choices take effect immediately.
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}

class VersesFaceDelegate extends WatchUi.WatchFaceDelegate {
    private var _view;

    function initialize(view) {
        WatchFaceDelegate.initialize();
        _view = view;
    }

    function onTap(clickEvent) {
        return _view.onTap(clickEvent);
    }

    function onPress(clickEvent) {
        return _view.onTap(clickEvent);
    }
}
