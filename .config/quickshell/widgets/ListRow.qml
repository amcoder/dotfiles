import QtQuick
import qs.config

// A hoverable, selectable row for the lists in popups and pickers. Children go
// into the rounded background, which fills the row inside `margins`.
MouseArea {
    id: root

    default property alias content: background.data

    property bool selected: false
    property int margins: 0

    signal activated

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: root.activated()

    Rectangle {
        id: background

        anchors.fill: parent
        anchors.margins: root.margins
        radius: 4

        color: {
            if (root.selected)
                return Theme.popupSelection;
            if (root.containsMouse)
                return Theme.popupHover;
            return "transparent";
        }
    }
}
