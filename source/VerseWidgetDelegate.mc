using Toybox.WatchUi;
using Toybox.System;

class VerseWidgetDelegate extends WatchUi.BehaviorDelegate {
    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() {
        _view.nextPage();
        WatchUi.requestUpdate();
        return true;
    }

    function onNextPage() {
        _view.nextPage();
        WatchUi.requestUpdate();
        return true;
    }

    function onPreviousPage() {
        _view.previousPage();
        WatchUi.requestUpdate();
        return true;
    }

    // Screen tap handler (for touchscreen device compatibility)
    function onTap(clickEvent) {
        _view.nextPage();
        WatchUi.requestUpdate();
        return true;
    }
}
