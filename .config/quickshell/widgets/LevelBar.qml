import QtQuick
import qs.config

// A read-only fill bar, 0..1. Not a slider: nothing that draws one is
// interactive yet.
Rectangle {
    id: root

    property real value: 0
    property color fillColor: Theme.blue

    implicitHeight: 8
    radius: height / 2
    color: Theme.surface0

    Rectangle {
        width: parent.width * Math.min(1, Math.max(0, root.value))
        height: parent.height
        radius: parent.radius
        color: root.fillColor
    }
}
