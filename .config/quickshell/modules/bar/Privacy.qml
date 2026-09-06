import QtQuick
import qs.config
import qs.modules.privacy
import qs.services
import qs.widgets

// The webcam and microphone indicators, shown only while something is
// capturing, and clicking to say what. One item rather than two: the question
// is the same one either icon raises, and it has a single answer.
//
// The binding on `visible` is also what warms PrivacyService, which nothing
// else references.
MouseArea {
    id: root

    visible: PrivacyService.cameraActive || PrivacyService.micActive
    implicitWidth: layout.implicitWidth
    cursorShape: Qt.PointingHandCursor

    onClicked: panel.toggle()

    // The card hangs off this item, so it cannot outlive it: with both icons
    // gone there is nothing left to anchor to, and nothing left to report.
    onVisibleChanged: {
        if (!root.visible)
            panel.expanded = false;
    }

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 8

        Icon {
            visible: PrivacyService.cameraActive
            name: "video-camera"
            color: Theme.red
        }

        Icon {
            visible: PrivacyService.micActive
            name: "microphone"
            color: Theme.red
        }
    }

    PrivacyPanel {
        id: panel

        anchorItem: root
    }
}
