import QtQuick
import qs.config

// LevelBar with a grab: pressing or dragging anywhere on the track emits the
// value under the cursor. The caller keeps `value` bound to its own state and
// writes through `moved`, so the binding is never broken.
Item {
    id: root

    property real value: 0
    property color fillColor: Theme.blue

    signal moved(real value)

    readonly property real fraction: Math.min(1, Math.max(0, root.value))

    implicitHeight: 18

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: height / 2
        color: Theme.surface0

        Rectangle {
            width: track.width * root.fraction
            height: track.height
            radius: track.radius
            color: root.fillColor
        }
    }

    Rectangle {
        x: track.width * root.fraction - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: width / 2
        color: root.fillColor
        border.color: Theme.popupBackground
        border.width: 2
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        onPressed: event => root.moved(Math.min(1, Math.max(0, event.x / root.width)))
        onPositionChanged: event => {
            if (pressed)
                root.moved(Math.min(1, Math.max(0, event.x / root.width)));
        }
    }
}
