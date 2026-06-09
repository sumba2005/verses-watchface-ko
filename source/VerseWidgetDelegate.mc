using Toybox.WatchUi;
using Toybox.System;

class VerseWidgetDelegate extends WatchUi.InputDelegate {
    private var _view;

    function initialize(view) {
        InputDelegate.initialize();
        _view = view;
    }

    // Screen tap handler
    function onTap(clickEvent) {
        _view.nextPage();
        WatchUi.requestUpdate();
        return true;
    }

    // SELECT button/enter handler (for physical button navigation)
    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            _view.nextPage();
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
