pragma Singleton

import QtQuick
import Quickshell

// Which transient card is showing, and for how long.
//
// One surface for every source rather than one per source: a volume keypress
// and a brightness keypress a moment apart should replace each other, not
// stack, which is what the notify-send OSDs this replaces got wrong. What each
// source looks like is the view's business, so only the name lives here.
Singleton {
    id: root

    property bool active: false
    property string source: ""

    function show(source: string): void {
        root.source = source;
        root.active = true;
        life.restart();
    }

    Timer {
        id: life

        interval: 2000

        onTriggered: root.active = false
    }
}
