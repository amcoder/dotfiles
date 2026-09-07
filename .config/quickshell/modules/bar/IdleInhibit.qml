import QtQuick
import qs.config
import qs.modules.idle
import qs.services
import qs.widgets

// Shown while something is holding the session awake, and clicking to say
// what -- the Wayland inhibitors that stop the lock, and the logind ones that
// stop logind's own idle action.
//
// The binding on `visible` is also what warms IdleInhibitService, which
// nothing else references.
MouseArea {
    id: root

    visible: IdleInhibitService.inhibited
    implicitWidth: cup.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        IdleInhibitService.refresh();
        panel.toggle();
    }

    // The card hangs off this item, so it cannot outlive it: with nothing left
    // inhibiting idle there is nothing left to anchor to, and nothing to say.
    onVisibleChanged: {
        if (!root.visible)
            panel.expanded = false;
    }

    Icon {
        id: cup

        anchors.centerIn: parent
        name: "coffee"
        color: Theme.yellow
    }

    IdleInhibitPanel {
        id: panel

        anchorItem: root
    }
}
