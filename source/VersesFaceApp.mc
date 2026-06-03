using Toybox.Application;
using Toybox.WatchUi;

// Watch face entry point. No background service, no permissions.
class VersesFaceApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new VersesFaceView() ];
    }

    // Fired when the user changes settings in Garmin Connect Mobile / on-device.
    // Repaint so the new choices take effect immediately.
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
